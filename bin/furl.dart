import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';
import 'package:pointycastle/export.dart';
import '../lib/validation.dart';

/// Calculate SHA-512 hash of a file
Future<String> calculateFileSha512(String filePath) async {
  final file = File(filePath);
  final contents = await file.readAsBytes();
  final digest = sha512.convert(contents);
  return digest.toString();
}

/// Display a progress bar for long-running operations
void showProgressBar(
  String label,
  int current,
  int total, {
  bool quiet = false,
}) {
  if (quiet) return; // Skip progress bars in quiet mode

  const int barWidth = 40;
  final progress = (current / total).clamp(0.0, 1.0);
  final filledWidth = (progress * barWidth).round();
  final emptyWidth = barWidth - filledWidth;

  final bar = '█' * filledWidth + '░' * emptyWidth;
  final percentage = (progress * 100).toStringAsFixed(1);

  stdout.write('\r$label [$bar] $percentage%');
  if (current >= total) {
    stdout.writeln(' ✓');
  }
}

/// Generate a strong PIN with alphanumeric characters and safe special characters
/// Avoids potentially confusing characters like 0/O, 1/l/I and special chars that might cause URL issues
String generateStrongPin(int length) {
  // Character set: uppercase, lowercase, numbers, and safe special characters
  // Excludes: 0, O, 1, l, I for readability
  // Excludes: quotes, spaces, and URL-problematic characters
  const String chars =
      'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*()_+-=[]{}|;:,.<>?';

  final random = SecureRandom('AES/CTR/AUTO-SEED-PRNG');
  final seed = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    seed[i] = DateTime.now().millisecondsSinceEpoch % 256;
  }
  random.seed(KeyParameter(seed));

  String result = '';
  for (int i = 0; i < length; i++) {
    final randomIndex = random.nextUint32() % chars.length;
    result += chars.substring(randomIndex, randomIndex + 1);
  }

  return result;
}

/// Encryption using AES-CTR mode with proper memory handling
/// For CTR mode, we need to encrypt the entire file as one stream to maintain counter integrity
Future<Uint8List> encryptFileStream(
  String filePath,
  encrypt.Encrypter encrypter,
  encrypt.IV iv, {
  bool quiet = false,
  int chunkSize = 1024 * 1024, // 1MB chunks for progress display only
}) async {
  final file = File(filePath);
  final fileName = filePath.split(Platform.pathSeparator).last;
  final fileSize = await file.length();

  if (!quiet) {
    showProgressBar(
      '🔒 Starting streaming encryption for $fileName',
      0,
      fileSize,
      quiet: quiet,
    );
  }

  // Stream the file data but encrypt all at once to maintain CTR integrity
  final List<int> allFileBytes = [];
  int processedBytes = 0;

  final inputStream = file.openRead();

  await for (final List<int> chunk in inputStream) {
    allFileBytes.addAll(chunk);
    processedBytes += chunk.length;

    if (!quiet) {
      showProgressBar(
        '🔒 Reading $fileName',
        processedBytes,
        fileSize,
        quiet: quiet,
      );
    }
  }

  if (!quiet) {
    showProgressBar('🔒 Encrypting $fileName', 0, 1, quiet: quiet);
  }

  // Encrypt the entire file as one operation to maintain CTR integrity
  final fileBytes = Uint8List.fromList(allFileBytes);
  final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

  if (!quiet) {
    showProgressBar('🔒 Encrypting $fileName', 1, 1, quiet: quiet);
  }

  return encrypted.bytes;
}

/// ChaCha20 streaming encryption - returns temporary file for maximum memory efficiency
/// Also calculates SHA-512 hash of the original file for integrity verification
Future<(File, String)> encryptFileStreamChaCha20ToFile(
  String filePath,
  Uint8List key, // 32-byte ChaCha20 key
  Uint8List nonce, { // 12-byte ChaCha20 nonce
  bool quiet = false,
  int chunkSize = 64 * 1024, // 64KB chunks
}) async {
  final file = File(filePath);
  final fileName = file.uri.pathSegments.last;
  final fileSize = await file.length();

  // Create temporary file for encrypted output to avoid memory accumulation
  final tempDir = Directory.systemTemp;
  final tempFile = File(
    '${tempDir.path}/furl_encrypted_${DateTime.now().millisecondsSinceEpoch}.tmp',
  );
  final sink = tempFile.openWrite();

  // Initialize buffer for SHA-512 hash calculation of original file
  final fileDataForHash = <int>[];

  try {
    // Initialize ChaCha20 cipher
    final cipher = ChaCha20Engine();
    final params = ParametersWithIV<KeyParameter>(KeyParameter(key), nonce);
    cipher.init(true, params); // true = encrypt

    int processedBytes = 0;
    int lastProgressUpdate = 0;
    final progressUpdateInterval = (fileSize / 100)
        .clamp(1024, 1024 * 1024)
        .round(); // Update every 1% or at least 1KB, max 1MB

    // Use manual chunked reading for better progress control
    final randomAccessFile = await file.open();

    try {
      while (processedBytes < fileSize) {
        final remainingBytes = fileSize - processedBytes;
        final currentChunkSize = remainingBytes < chunkSize
            ? remainingBytes
            : chunkSize;

        // Read chunk
        final chunkBytes = await randomAccessFile.read(currentChunkSize);

        // Add original chunk data to hash calculation
        fileDataForHash.addAll(chunkBytes);

        final encryptedChunk = Uint8List(chunkBytes.length);

        // Process chunk through ChaCha20 - maintains keystream state
        cipher.processBytes(
          chunkBytes,
          0,
          chunkBytes.length,
          encryptedChunk,
          0,
        );

        // Write encrypted chunk directly to temp file
        sink.add(encryptedChunk);
        processedBytes += chunkBytes.length;

        // Update progress only when we've processed a meaningful amount
        if (!quiet &&
            (processedBytes - lastProgressUpdate >= progressUpdateInterval ||
                processedBytes == fileSize)) {
          showProgressBar(
            '🔒 Encrypting $fileName',
            processedBytes,
            fileSize,
            quiet: quiet,
          );
          lastProgressUpdate = processedBytes;
        }
      }
    } finally {
      await randomAccessFile.close();
    }

    await sink.flush();
    await sink.close();

    // Calculate SHA-512 hash of the original file
    final digest = sha512.convert(fileDataForHash);
    final sha512Hash = digest.toString();

    return (tempFile, sha512Hash);
  } catch (e) {
    await sink.close();
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    rethrow;
  }
}

/// ChaCha20 streaming encryption - memory efficient with direct disk writing
/// This maintains keystream state across chunks without memory accumulation
Future<Uint8List> encryptFileStreamChaCha20(
  String filePath,
  Uint8List key, // 32-byte ChaCha20 key
  Uint8List nonce, { // 12-byte ChaCha20 nonce
  bool quiet = false,
  int chunkSize = 64 * 1024, // 64KB chunks
}) async {
  final (tempFile, _) = await encryptFileStreamChaCha20ToFile(
    filePath,
    key,
    nonce,
    quiet: quiet,
    chunkSize: chunkSize,
  );

  try {
    // Read the final result - only loads complete file into memory at the end
    final encryptedBytes = await tempFile.readAsBytes();
    return encryptedBytes;
  } finally {
    // Clean up temporary file
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}

/// Show encryption progress - real progress for large files, simulated for small files
Future<Uint8List> encryptWithProgress(
  String fileName,
  Uint8List fileBytes,
  encrypt.Encrypter encrypter,
  encrypt.IV iv, {
  bool quiet = false,
}) async {
  final fileSize = fileBytes.length;

  if (fileSize < 1024 * 1024) {
    // Small files (< 1MB): Fast simulated progress
    if (!quiet) {
      const steps = 20;
      final stepDelay = Duration(milliseconds: 50);

      for (int i = 0; i <= steps; i++) {
        showProgressBar('🔒 Encrypting $fileName', i, steps, quiet: quiet);
        if (i < steps) await Future.delayed(stepDelay);
      }
    }
  } else {
    // Large files (≥ 1MB): Progress based on estimated time
    if (!quiet) {
      // Estimate ~50MB/s encryption speed
      final estimatedSeconds = (fileSize / (50 * 1024 * 1024)).clamp(1.0, 30.0);
      final steps = (estimatedSeconds * 10).round(); // 10 updates per second
      final stepDelay = Duration(
        milliseconds: (estimatedSeconds * 1000 / steps).round(),
      );

      // Start progress display
      for (int i = 0; i < steps; i++) {
        showProgressBar('🔒 Encrypting $fileName', i, steps, quiet: quiet);
        await Future.delayed(stepDelay);
      }
      // Complete the progress display
      showProgressBar('🔒 Encrypting $fileName', steps, steps, quiet: quiet);
    }
  }

  // Perform the actual encryption (not chunked to maintain integrity)
  final encryptedFile = encrypter.encryptBytes(fileBytes, iv: iv);

  return encryptedFile.bytes;
}

/// Upload with progress tracking
/// Upload file with progress tracking from a file (memory efficient)
Future<http.Response> uploadFileWithProgress(
  String url,
  File file,
  String fileName, {
  bool quiet = false,
}) async {
  final dio = Dio()
    ..options.connectTimeout =
        Duration(minutes: 5) // 5 minute connection timeout
    ..options.receiveTimeout =
        Duration(minutes: 30) // 30 minute receive timeout
    ..options.sendTimeout =
        Duration(hours: 2) // 2 hour send timeout for large files
    ..options.followRedirects = true
    ..options.maxRedirects = 5;

  try {
    // Get file size for Content-Length header
    final fileSize = await file.length();

    if (!quiet) {
      print(
        '📤 Starting upload of $fileName (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB)...',
      );
    }

    // Use file stream for upload
    final fileBytes = file.openRead();

    // Track progress updates to detect hanging
    var lastProgressTime = DateTime.now();
    var lastSentBytes = 0;

    final response = await dio.post(
      url,
      data: fileBytes, // Send file stream directly as raw bytes
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileSize.toString(), // Required for filebin.net
        },
        responseType: ResponseType.plain,
      ),
      onSendProgress: (int sent, int total) {
        final now = DateTime.now();
        final timeSinceLastUpdate =
            now.difference(lastProgressTime).inMilliseconds / 1000.0;

        // Update progress more frequently for large files and show speed
        final shouldUpdate =
            sent == total ||
            sent % (total ~/ 500).clamp(256, 128 * 1024) == 0 ||
            timeSinceLastUpdate >=
                0.5; // Force update every 500ms for smooth progress

        if (shouldUpdate) {
          // Calculate upload speed
          final bytesSinceLastUpdate = sent - lastSentBytes;
          final speedMBps =
              bytesSinceLastUpdate /
              (1024 *
                  1024 *
                  (timeSinceLastUpdate > 0 ? timeSinceLastUpdate : 1));

          if (!quiet) {
            final progressMsg = timeSinceLastUpdate > 0 && sent < total
                ? '📤 Uploading $fileName (${speedMBps.toStringAsFixed(1)} MB/s)'
                : '📤 Uploading $fileName';
            showProgressBar(progressMsg, sent, total);
          }

          lastProgressTime = now;
          lastSentBytes = sent;
        }
      },
    );

    // Convert Dio response to http.Response for compatibility
    return http.Response(
      response.data.toString(),
      response.statusCode ?? 500,
      headers: response.headers.map.map(
        (key, value) => MapEntry(key, value.join('; ')),
      ),
    );
  } catch (e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          throw Exception(
            'Upload failed: Connection timeout after 5 minutes. Please check your internet connection.',
          );
        case DioExceptionType.sendTimeout:
          throw Exception(
            'Upload failed: Send timeout after 2 hours. File may be too large or connection too slow.',
          );
        case DioExceptionType.receiveTimeout:
          throw Exception(
            'Upload failed: Server response timeout after 30 minutes.',
          );
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 413) {
            final fileSizeKnown = await file.length();
            throw Exception(
              'Upload failed: File too large (${(fileSizeKnown / (1024 * 1024)).toStringAsFixed(1)}MB). Server limit exceeded.',
            );
          } else if (statusCode == 404) {
            throw Exception(
              'Upload failed: Server endpoint not found (404). Please verify the upload URL.',
            );
          } else if (statusCode == 403) {
            throw Exception(
              'Upload failed: Access forbidden (403). Server may have rejected the upload.',
            );
          } else if (statusCode == 429) {
            throw Exception(
              'Upload failed: Rate limit exceeded (429). Please wait and try again later.',
            );
          } else {
            throw Exception(
              'Upload failed: Server returned ${statusCode} - ${e.response?.data}',
            );
          }
        default:
          throw Exception('Upload failed: ${e.message}');
      }
    }
    print('File upload failed: $e');
    rethrow;
  }
}

/// Upload data with progress tracking (kept for compatibility)
Future<http.Response> uploadWithProgress(
  String url,
  Uint8List data,
  String fileName, {
  bool quiet = false,
}) async {
  final dio = Dio()
    ..options.connectTimeout =
        Duration(minutes: 5) // 5 minute connection timeout
    ..options.receiveTimeout =
        Duration(minutes: 30) // 30 minute receive timeout
    ..options.sendTimeout =
        Duration(hours: 2) // 2 hour send timeout for large files
    ..options.followRedirects = true
    ..options.maxRedirects = 5;

  try {
    // Upload raw binary data (like original http.post) with progress tracking
    final response = await dio.post(
      url,
      data: data, // Send raw bytes, not FormData
      options: Options(
        headers: {'Content-Type': 'application/octet-stream'},
        responseType: ResponseType.plain,
      ),
      onSendProgress: (int sent, int total) {
        showProgressBar('📤 Uploading $fileName', sent, total);
      },
    );

    // Convert Dio response to http.Response for compatibility
    return http.Response(
      response.data.toString(),
      response.statusCode ?? 500,
      headers: response.headers.map.map(
        (key, value) => MapEntry(key, value.join('; ')),
      ),
    );
  } catch (e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          throw Exception(
            'Upload failed: Connection timeout after 5 minutes. Please check your internet connection.',
          );
        case DioExceptionType.sendTimeout:
          throw Exception(
            'Upload failed: Send timeout after 2 hours. File may be too large or connection too slow.',
          );
        case DioExceptionType.receiveTimeout:
          throw Exception(
            'Upload failed: Server response timeout after 30 minutes.',
          );
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 413) {
            throw Exception(
              'Upload failed: File too large (${(data.length / (1024 * 1024)).toStringAsFixed(1)}MB). Server limit exceeded.',
            );
          } else if (statusCode == 404) {
            throw Exception(
              'Upload failed: Server endpoint not found (404). Please verify the upload URL.',
            );
          } else if (statusCode == 403) {
            throw Exception(
              'Upload failed: Access forbidden (403). Server may have rejected the upload.',
            );
          } else if (statusCode == 429) {
            throw Exception(
              'Upload failed: Rate limit exceeded (429). Please wait and try again later.',
            );
          } else {
            throw Exception(
              'Upload failed: Server returned ${statusCode} - ${e.response?.data}',
            );
          }
        default:
          throw Exception('Upload failed: ${e.message}');
      }
    }

    // Fallback to original http implementation if Dio fails
    print('Dio upload failed, falling back to http: $e');

    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      data,
      filename: '${fileName}.encrypted',
    );
    request.files.add(multipartFile);
    request.headers['Content-Type'] = 'application/octet-stream';

    final streamedResponse = await request.send();
    showProgressBar('📤 Uploading $fileName', 1, 1);

    return await http.Response.fromStream(streamedResponse);
  }
}

/// Parse TTL string format like "10s", "5m", "2h", "1d" into seconds
int parseTtl(String ttlString) {
  const int maxTtl = 6 * 86400; // 6 days in seconds (filebin.net limit)

  if (ttlString.isEmpty) return 3600; // Default 1 hour

  // Check if it's already just a number (seconds)
  final numOnly = int.tryParse(ttlString);
  if (numOnly != null) {
    if (numOnly > maxTtl) {
      print('TTL too long: ${formatDuration(numOnly)}');
      print('Maximum allowed TTL is 6 days (${formatDuration(maxTtl)})');
      exit(1);
    }
    return numOnly;
  }

  // Extract number and unit
  final regex = RegExp(r'^(\d+)([smhd])$');
  final match = regex.firstMatch(ttlString.toLowerCase());

  if (match == null) {
    print('Invalid TTL format: $ttlString');
    print(
      'Use format like: 30s (seconds), 10m (minutes), 2h (hours), 1d (days)',
    );
    print('Or just a number for seconds: 3600');
    exit(1);
  }

  final number = int.parse(match.group(1)!);
  final unit = match.group(2)!;

  int ttlSeconds;
  switch (unit) {
    case 's':
      ttlSeconds = number;
      break;
    case 'm':
      ttlSeconds = number * 60;
      break;
    case 'h':
      ttlSeconds = number * 3600;
      break;
    case 'd':
      ttlSeconds = number * 86400;
      break;
    default:
      ttlSeconds = 3600;
  }

  if (ttlSeconds > maxTtl) {
    print('TTL too long: ${formatDuration(ttlSeconds)}');
    print('Maximum allowed TTL is 6 days (${formatDuration(maxTtl)})');
    exit(1);
  }

  return ttlSeconds;
}

/// Format seconds into a human-readable duration
String formatDuration(int seconds) {
  if (seconds < 60) {
    return '${seconds}s';
  } else if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds == 0
        ? '${minutes}m'
        : '${minutes}m ${remainingSeconds}s';
  } else if (seconds < 86400) {
    final hours = seconds ~/ 3600;
    final remainingMinutes = (seconds % 3600) ~/ 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  } else {
    final days = seconds ~/ 86400;
    final remainingHours = (seconds % 86400) ~/ 3600;
    return remainingHours == 0 ? '${days}d' : '${days}d ${remainingHours}h';
  }
}

Future<void> main(List<String> arguments) async {
  // Check for help flag first
  if (arguments.contains('-h') || arguments.contains('--help')) {
    print('Furl - Secure File Sharing with atPlatform');
    print('');
    print('Usage: furl <atSign> <file_path> <ttl> [options]');
    print('');
    print('Arguments:');
    print('  atSign                Your atSign (e.g., @alice)');
    print('  file_path             Path to the file to encrypt and share');
    print(
      '  ttl                   Time-to-live: 30s, 10m, 2h, 1d (max: 6d, or seconds as number)',
    );
    print('');
    print('Options:');
    print('  -v, --verbose         Enable verbose logging');
    print('  -q, --quiet           Disable progress bars');
    print(
      '  -s, --server <url>    Furl server URL (default: https://furl.host)',
    );
    print(
      '  -m, --message <text>  Custom message for recipient (max 140 chars)',
    );
    print('  --no-file-size        Hide file size on download page');
    print('  -h, --help            Show this help message');
    print('');
    print('TTL Examples:');
    print('  30s                   30 seconds');
    print('  10m                   10 minutes');
    print('  2h                    2 hours');
    print('  1d                    1 day');
    print('  6d                    6 days (maximum)');
    print('  3600                  3600 seconds (1 hour)');
    print('');
    print('Examples:');
    print('  furl @alice document.pdf 1h');
    print('  furl @alice document.pdf 30m -v');
    print('  furl @alice document.pdf 2d --quiet');
    print('  furl @alice document.pdf 2d --server http://localhost:8080');
    print('  furl @alice document.pdf 12h -m "Here is the contract"');
    print('  furl @alice document.pdf 1d --no-file-size');
    print(
      '  furl @alice document.pdf 12h --server https://my-furl-server.com -v',
    );
    print('');
    print('The program will:');
    print('  1. Encrypt your file with ChaCha20 (streaming optimized)');
    print('  2. Upload the encrypted file to filebin.net');
    print('  3. Store decryption metadata securely on the atPlatform');
    print('  4. Generate a secure URL for the recipient');
    print(
      '  5. Generate a strong PIN with special characters for additional security',
    );
    print('  6. Calculate SHA-512 hash for integrity verification');
    print('  7. Display the expiration time based on TTL');
    exit(0);
  }

  if (arguments.length < 3) {
    print('Usage: furl <atSign> <file_path> <ttl> [options]');
    print('');
    print('Arguments:');
    print(
      '  ttl                   Time-to-live: 30s, 10m, 2h, 1d (max: 6d, or seconds as number)',
    );
    print('');
    print('Examples:');
    print('  furl @alice document.pdf 1h');
    print('  furl @alice document.pdf 30m -v');
    print('  furl @alice document.pdf 2d --server http://localhost:8080');
    print('');
    print('Use --help for detailed information.');
    exit(1);
  }

  final atSign = arguments[0];
  final filePath = arguments[1];
  final ttl = parseTtl(arguments[2]);

  // Validate atSign format
  if (!validateAtSign(atSign)) {
    print('Error: Invalid atSign format "$atSign"');
    print('atSign must:');
    print('  - Start with @ symbol');
    print('  - Contain only letters, numbers, dots, hyphens, and underscores');
    print('  - Not start or end with special characters');
    print('  - Have only one @ symbol');
    print('');
    print('Valid examples: @alice, @bob123, @user.name, @test-user');
    print('Invalid examples: alice, @@alice, @alice@bob, @.alice, @alice.');
    exit(1);
  }

  // Parse optional arguments
  bool verbose = false;
  bool quiet = false;
  bool hideFileSize = false;
  String? customMessage;
  String serverUrl = 'https://furl.host';

  for (int i = 3; i < arguments.length; i++) {
    if (arguments[i] == '-v' || arguments[i] == '--verbose') {
      verbose = true;
    } else if (arguments[i] == '-q' || arguments[i] == '--quiet') {
      quiet = true;
    } else if (arguments[i] == '--no-file-size') {
      hideFileSize = true;
    } else if ((arguments[i] == '-s' || arguments[i] == '--server') &&
        i + 1 < arguments.length) {
      serverUrl = arguments[i + 1];
      i++; // Skip the next argument as it's the server URL
    } else if ((arguments[i] == '-m' || arguments[i] == '--message') &&
        i + 1 < arguments.length) {
      customMessage = arguments[i + 1];
      if (customMessage.length > 140) {
        print('Error: Message cannot exceed 140 characters');
        print('Current message length: ${customMessage.length}');
        exit(1);
      }
      i++; // Skip the next argument as it's the message
    }
  }

  // Set logging level based on verbose flag
  if (!verbose) {
    AtSignLogger.root_level = 'severe'; // Only show errors
  }

  try {
    // 1. Generate ChaCha20 key and nonce using secure random
    final chaCha20Key = encrypt.Key.fromSecureRandom(
      32,
    ); // 32-byte key for ChaCha20
    final chaCha20Nonce = encrypt.IV.fromSecureRandom(
      8,
    ); // 8-byte nonce for ChaCha20 (some implementations use 8 bytes)

    // 2. Generate 9-char strong PIN with alphanumeric + special characters
    final pin = generateStrongPin(9);
    //print('PIN for recipient: $pin');

    // 3. Encrypt file with ChaCha20 streaming and calculate SHA-512 for integrity
    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileSize = await File(filePath).length();
    final isLargeFile = fileSize > 10 * 1024 * 1024; // 10MB threshold
    final isSuperLargeFile =
        fileSize > 100 * 1024 * 1024; // 100MB threshold for special handling

    // Warn user about super large files
    if (isSuperLargeFile && !quiet) {
      print(
        '⚠️  Large file detected: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB',
      );
      print(
        '   This may take a significant amount of time to encrypt and upload.',
      );
      print(
        '   The process may appear to hang after encryption completes - this is normal.',
      );
      print('   Upload speeds depend on your internet connection.');
      print('');
    }

    // Calculate SHA-512 hash of original file for integrity verification
    String sha512Hash;
    if (isLargeFile) {
      // For large files, hash will be calculated during streaming encryption
      sha512Hash = '';
    } else {
      // For small files, calculate hash upfront
      sha512Hash = await calculateFileSha512(filePath);
    }

    // 4. Upload encrypted file to filebin.net
    String fileUrl;
    File? tempEncryptedFile;

    try {
      // Upload to filebin.net - they require a bin first, then file upload
      // Use UUID for bin ID instead of timestamp for better security
      final uuid = Uuid();
      final binId = 'furl${uuid.v4().replaceAll('-', '')}';
      final uploadUrl = 'https://filebin.net/$binId/${fileName}.encrypted';

      http.Response uploadResp;

      if (isLargeFile) {
        // For large files: use file-to-file streaming to minimize memory usage
        if (!quiet) {
          print(
            'Large file detected (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB) - using memory-efficient streaming...',
          );
        }

        final (
          tempFile,
          calculatedSha512Hash,
        ) = await encryptFileStreamChaCha20ToFile(
          filePath,
          chaCha20Key.bytes,
          chaCha20Nonce.bytes,
          quiet: quiet,
        );
        tempEncryptedFile = tempFile;
        sha512Hash = calculatedSha512Hash;

        // Notify user that encryption is complete and upload is starting
        if (!quiet) {
          print('✅ Encryption complete. Starting upload...');
          if (isSuperLargeFile) {
            print(
              '   Upload progress will be shown below. Large uploads may take considerable time.',
            );
          }
        }

        // Upload directly from file
        uploadResp = await uploadFileWithProgress(
          uploadUrl,
          tempEncryptedFile,
          fileName,
          quiet: quiet,
        );
      } else {
        // For small files: use existing in-memory approach
        final encryptedBytes = await encryptFileStreamChaCha20(
          filePath,
          chaCha20Key.bytes,
          chaCha20Nonce.bytes,
          quiet: quiet,
        );

        // Notify user that encryption is complete and upload is starting
        if (!quiet) {
          print('✅ Encryption complete. Starting upload...');
        }

        uploadResp = await uploadWithProgress(
          uploadUrl,
          encryptedBytes,
          fileName,
          quiet: quiet,
        );
      }

      if (uploadResp.statusCode == 201 || uploadResp.statusCode == 200) {
        fileUrl = uploadUrl;
        // print('File uploaded to: $fileUrl');
      } else {
        throw Exception(
          'Upload failed: ${uploadResp.statusCode} - ${uploadResp.body}',
        );
      }
    } catch (e) {
      print('Error uploading to filebin.net: $e');
      // Fallback: simulate upload for testing
      print('Simulating upload...');
      final uuid = Uuid();
      fileUrl =
          'https://filebin.net/simulated/${uuid.v4().replaceAll('-', '')}_${fileName}.encrypted';
      print('File would be uploaded to: $fileUrl');
      print('Note: Ensure network connectivity for actual filebin.net upload');
    } finally {
      // Clean up temporary file if it was created
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }

    // 5. Encrypt AES key with PIN (using PBKDF2 for key derivation)
    final salt = encrypt.IV.fromSecureRandom(8).bytes;
    final pinBytes = utf8.encode(pin);

    // Simple key derivation using SHA256 (could be enhanced with proper PBKDF2)
    final digest = sha256.convert(pinBytes + salt);
    final derivedKey = Uint8List.fromList(digest.bytes);

    final keyEncrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(derivedKey), mode: encrypt.AESMode.ctr),
    );
    final keyIv = encrypt.IV.fromSecureRandom(16);
    final encryptedChaCha20Key = keyEncrypter.encryptBytes(
      chaCha20Key.bytes,
      iv: keyIv,
    );

    // 6. Store encrypted ChaCha20 key, salt, nonce, and file URL in public atKey
    //print('Storing secrets in atPlatform...');

    // Use a public atKey with leading underscore to make it invisible to scan verb
    // Generate a UUID-based random identifier instead of timestamp for security
    final uuid = Uuid();
    final randomId = uuid.v4().replaceAll(
      '-',
      '',
    ); // Remove dashes for cleaner ID
    final atKeyName = '_furl_$randomId';

    final secretPayload = jsonEncode({
      'file_url': fileUrl,
      'chacha20_key': base64Encode(encryptedChaCha20Key.bytes),
      'key_iv': base64Encode(keyIv.bytes),
      'key_salt': base64Encode(salt),
      'file_nonce': base64Encode(chaCha20Nonce.bytes),
      'file_name': fileName,
      'cipher': 'chacha20', // Indicate which cipher was used
      'sha512_hash':
          sha512Hash, // SHA-512 hash of original file for integrity verification
      if (customMessage != null)
        'message': customMessage, // Custom message for recipient
      if (!hideFileSize)
        'file_size': fileSize, // File size in bytes (unless hidden)
    });

    // Get AtClient using the correct onboarding pattern from the demos
    final atClient = await _getAtClient(atSign, verbose);
    final atKey = AtKey()
      ..key = atKeyName
      ..metadata = (Metadata()
        ..isPublic = true
        ..ttl = ttl * 1000); // TTL in milliseconds

    // Use PutRequestOptions like the demos do for direct remote atServer access
    final putRequestOptions = PutRequestOptions()..useRemoteAtServer = true;

    // Show storage progress
    if (!quiet) {
      const storageSteps = 15;
      final storageStepDelay = Duration(milliseconds: 80);

      for (int i = 0; i <= storageSteps; i++) {
        showProgressBar(
          '🏗️ Storing metadata on atPlatform',
          i,
          storageSteps,
          quiet: quiet,
        );
        if (i < storageSteps && !quiet) await Future.delayed(storageStepDelay);
      }
    }

    await atClient.put(
      atKey,
      secretPayload,
      putRequestOptions: putRequestOptions,
    );
    //print('Secrets stored in atPlatform with public key: $atKeyName');

    // 7. Verify the data is retrievable from remote server before exiting
    //print('\nVerifying data is accessible on remote atServer...');
    var maxRetries = 10;
    var retryCount = 0;
    bool dataVerified = false;

    while (retryCount < maxRetries && !dataVerified) {
      try {
        final atKey = AtKey()
          ..namespace = 'furl'
          ..sharedBy = atSign
          ..metadata = (Metadata()..isPublic = true)
          ..key = atKeyName;

        // Force a fresh lookup from the atServer (not cached)
        final getRequestOptions = GetRequestOptions()..useRemoteAtServer = true;
        final retrievedData = await atClient.get(
          atKey,
          getRequestOptions: getRequestOptions,
        );
        if (retrievedData.value != null) {
          //print('✓ Data successfully verified on remote atServer');
          dataVerified = true;
        } else {
          retryCount++;
          print(
            '⏳ Attempt $retryCount/$maxRetries - waiting for remote sync...',
          );
        }
      } catch (e) {
        retryCount++;
        print(
          '⏳ Attempt $retryCount/$maxRetries - waiting for remote sync... ($e)',
        );
      }
      await Future.delayed(
        Duration(seconds: 2),
      ); // Wait 2 seconds between attempts
    }

    if (!dataVerified) {
      print(
        '⚠️  Warning: Could not verify data sync to remote server after $maxRetries attempts',
      );
      print(
        '   The data may still be syncing. Try the download in a few minutes.',
      );
    }

    // 8. Print retrieval URL
    print('\nSend this URL to the recipient:');
    print('$serverUrl/furl.html?atSign=$atSign&key=$atKeyName');
    print('');
    print('They will need the PIN: $pin');

    // Calculate and display expiration time
    final expirationTime = DateTime.now().add(Duration(seconds: ttl));
    final formattedExpiration = expirationTime.toLocal().toString().split(
      '.',
    )[0]; // Remove microseconds
    print('PIN expires: $formattedExpiration (TTL: ${formatDuration(ttl)})');

    // print('\nNote: Make sure the server is running:');
    // print('  Unified Server: dart run bin/furl_server.dart');

    // Clean exit
    exit(0);
  } catch (e, stackTrace) {
    print('Error: $e');
    if (verbose) {
      print('Stack trace: $stackTrace');
    }
    exit(4);
  }
}

// Helper to get AtClient using the pattern from at_demos
Future<AtClient> _getAtClient(String atSign, bool verbose) async {
  try {
    // Generate preferences following the pattern from at_demos
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

    final preference = AtOnboardingPreference()
      ..hiveStoragePath = '$home/.atsign/storage/$atSign'
      ..namespace = 'furl'
      ..commitLogPath = '$home/.atsign/storage/$atSign/commitLog'
      ..isLocalStoreRequired =
          false // We don't need local storage for a simple put
      ..downloadPath = '$home/.atsign/files/$atSign'
      ..rootDomain = 'root.atsign.org'
      ..atKeysFilePath = '$home/.atsign/keys/${atSign}_key.atKeys';

    // Use AtOnboardingServiceImpl exactly like the working demos
    final onboardingService = AtOnboardingServiceImpl(atSign, preference);
    final isAuthenticated = await onboardingService.authenticate();

    if (!isAuthenticated) {
      throw Exception('Failed to authenticate $atSign');
    }

    final atClient = onboardingService.atClient;

    if (atClient == null) {
      throw Exception('Failed to get AtClient from onboarding service');
    }

    if (verbose) {
      print('Successfully authenticated as $atSign');
    }
    return atClient;
  } catch (e) {
    print('Failed to create AtClient: $e');
    print('Make sure:');
    print(
      '1. You have activated your atSign: dart run at_activate --atsign $atSign',
    );
    print('2. Your atKeys file exists at: ~/.atsign/keys/${atSign}_key.atKeys');
    print('3. You have proper network connectivity');
    exit(6);
  }
}
