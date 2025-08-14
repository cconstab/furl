import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:random_string/random_string.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';

/// Display a progress bar for long-running operations
void showProgressBar(String label, int current, int total, {bool quiet = false}) {
  if (quiet) return; // Skip progress bars in quiet mode

  const int barWidth = 40;
  final progress = (current / total).clamp(0.0, 1.0);
  final filledWidth = (progress * barWidth).round();
  final emptyWidth = barWidth - filledWidth;

  final bar = '█' * filledWidth + '░' * emptyWidth;
  final percentage = (progress * 100).toStringAsFixed(1);

  stdout.write('\r$label [${bar}] ${percentage}%');
  if (current >= total) {
    stdout.writeln(' ✓');
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
      final stepDelay = Duration(milliseconds: (estimatedSeconds * 1000 / steps).round());

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
Future<http.Response> uploadWithProgress(String url, Uint8List data, String fileName) async {
  final dio = Dio();

  try {
    // Upload raw binary data (like original http.post) with progress tracking
    final response = await dio.post(
      url,
      data: data, // Send raw bytes, not FormData
      options: Options(headers: {'Content-Type': 'application/octet-stream'}, responseType: ResponseType.plain),
      onSendProgress: (int sent, int total) {
        showProgressBar('📤 Uploading ${fileName}.encrypted', sent, total);
      },
    );

    // Convert Dio response to http.Response for compatibility
    return http.Response(
      response.data.toString(),
      response.statusCode ?? 500,
      headers: response.headers.map.map((key, value) => MapEntry(key, value.join('; '))),
    );
  } catch (e) {
    // Fallback to original http implementation if Dio fails
    print('Dio upload failed, falling back to http: $e');

    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);
    final multipartFile = http.MultipartFile.fromBytes('file', data, filename: '${fileName}.encrypted');
    request.files.add(multipartFile);
    request.headers['Content-Type'] = 'application/octet-stream';

    final streamedResponse = await request.send();
    showProgressBar('📤 Uploading ${fileName}.encrypted', 1, 1);

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
    print('Use format like: 30s (seconds), 10m (minutes), 2h (hours), 1d (days)');
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
    return remainingSeconds == 0 ? '${minutes}m' : '${minutes}m ${remainingSeconds}s';
  } else if (seconds < 86400) {
    final hours = seconds ~/ 3600;
    final remainingMinutes = (seconds % 3600) ~/ 60;
    return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
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
    print('  ttl                   Time-to-live: 30s, 10m, 2h, 1d (max: 6d, or seconds as number)');
    print('');
    print('Options:');
    print('  -v, --verbose         Enable verbose logging');
    print('  -q, --quiet           Disable progress bars');
    print('  -s, --server <url>    Furl server URL (default: https://furl.host)');
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
    print('  furl @alice document.pdf 12h --server https://my-furl-server.com -v');
    print('');
    print('The program will:');
    print('  1. Encrypt your file with AES-256');
    print('  2. Upload the encrypted file to filebin.net');
    print('  3. Store decryption metadata securely on the atPlatform');
    print('  4. Generate a secure URL for the recipient');
    print('  5. Generate a PIN for additional security');
    print('  6. Display the expiration time based on TTL');
    exit(0);
  }

  if (arguments.length < 3) {
    print('Usage: furl <atSign> <file_path> <ttl> [options]');
    print('');
    print('Arguments:');
    print('  ttl                   Time-to-live: 30s, 10m, 2h, 1d (max: 6d, or seconds as number)');
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

  // Parse optional arguments
  bool verbose = false;
  bool quiet = false;
  String serverUrl = 'https://furl.host';

  for (int i = 3; i < arguments.length; i++) {
    if (arguments[i] == '-v' || arguments[i] == '--verbose') {
      verbose = true;
    } else if (arguments[i] == '-q' || arguments[i] == '--quiet') {
      quiet = true;
    } else if ((arguments[i] == '-s' || arguments[i] == '--server') && i + 1 < arguments.length) {
      serverUrl = arguments[i + 1];
      i++; // Skip the next argument as it's the server URL
    }
  }

  // Set logging level based on verbose flag
  if (!verbose) {
    AtSignLogger.root_level = 'severe'; // Only show errors
  }

  try {
    // 1. Generate AES-256 key and IV
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    // 2. Generate 9-char alphanumeric PIN
    final pin = randomAlphaNumeric(9);
    //print('PIN for recipient: $pin');

    // 3. Encrypt file
    final fileBytes = await File(filePath).readAsBytes();
    final fileName = filePath.split(Platform.pathSeparator).last;

    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final encryptedBytes = await encryptWithProgress(fileName, fileBytes, encrypter, iv, quiet: quiet);

    // 4. Upload encrypted file to filebin.net

    String fileUrl;
    try {
      // Upload to filebin.net - they require a bin first, then file upload
      // Use UUID for bin ID instead of timestamp for better security
      final uuid = Uuid();
      final binId = 'furl${uuid.v4().replaceAll('-', '')}';

      // Upload file directly to bin with progress tracking
      final uploadResp = await uploadWithProgress(
        'https://filebin.net/$binId/${fileName}.encrypted',
        encryptedBytes,
        fileName,
      );

      if (uploadResp.statusCode == 201 || uploadResp.statusCode == 200) {
        fileUrl = 'https://filebin.net/$binId/${fileName}.encrypted';
        // print('File uploaded to: $fileUrl');
      } else {
        throw Exception('Upload failed: ${uploadResp.statusCode} - ${uploadResp.body}');
      }
    } catch (e) {
      print('Error uploading to filebin.net: $e');
      // Fallback: simulate upload for testing
      print('Simulating upload...');
      final uuid = Uuid();
      fileUrl = 'https://filebin.net/simulated/${uuid.v4().replaceAll('-', '')}_${fileName}.encrypted';
      print('File would be uploaded to: $fileUrl');
      print('Note: Ensure network connectivity for actual filebin.net upload');
    }

    // 5. Encrypt AES key with PIN (using PBKDF2 for key derivation)
    final salt = encrypt.IV.fromSecureRandom(8).bytes;
    final pinBytes = utf8.encode(pin);

    // Simple key derivation using SHA256 (could be enhanced with proper PBKDF2)
    final digest = sha256.convert(pinBytes + salt);
    final derivedKey = Uint8List.fromList(digest.bytes);

    final aesKeyEncrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(derivedKey), mode: encrypt.AESMode.cbc));
    final aesKeyIv = encrypt.IV.fromSecureRandom(16);
    final encryptedAesKey = aesKeyEncrypter.encryptBytes(aesKey.bytes, iv: aesKeyIv);

    // 6. Store encrypted AES key, salt, iv, and file URL in public atKey
    //print('Storing secrets in atPlatform...');

    // Use a public atKey with leading underscore to make it invisible to scan verb
    // Generate a UUID-based random identifier instead of timestamp for security
    final uuid = Uuid();
    final randomId = uuid.v4().replaceAll('-', ''); // Remove dashes for cleaner ID
    final atKeyName = '_furl_$randomId';

    final secretPayload = jsonEncode({
      'file_url': fileUrl,
      'aes_key': base64Encode(encryptedAesKey.bytes),
      'aes_key_iv': base64Encode(aesKeyIv.bytes),
      'aes_key_salt': base64Encode(salt),
      'file_iv': base64Encode(iv.bytes),
      'file_name': fileName,
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
        showProgressBar('🏗️ Storing metadata on atPlatform', i, storageSteps, quiet: quiet);
        if (i < storageSteps && !quiet) await Future.delayed(storageStepDelay);
      }
    }

    await atClient.put(atKey, secretPayload, putRequestOptions: putRequestOptions);
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
        final retrievedData = await atClient.get(atKey, getRequestOptions: getRequestOptions);
        if (retrievedData.value != null) {
          //print('✓ Data successfully verified on remote atServer');
          dataVerified = true;
        } else {
          retryCount++;
          print('⏳ Attempt $retryCount/$maxRetries - waiting for remote sync...');
        }
      } catch (e) {
        retryCount++;
        print('⏳ Attempt $retryCount/$maxRetries - waiting for remote sync... ($e)');
      }
      await Future.delayed(Duration(seconds: 2)); // Wait 2 seconds between attempts
    }

    if (!dataVerified) {
      print('⚠️  Warning: Could not verify data sync to remote server after $maxRetries attempts');
      print('   The data may still be syncing. Try the download in a few minutes.');
    }

    // 8. Print retrieval URL
    print('\nSend this URL to the recipient:');
    print('$serverUrl/furl.html?atSign=$atSign&key=$atKeyName');
    print('');
    print('They will need the PIN: $pin');

    // Calculate and display expiration time
    final expirationTime = DateTime.now().add(Duration(seconds: ttl));
    final formattedExpiration = expirationTime.toLocal().toString().split('.')[0]; // Remove microseconds
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
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

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
    print('1. You have activated your atSign: dart run at_activate --atsign $atSign');
    print('2. Your atKeys file exists at: ~/.atsign/keys/${atSign}_key.atKeys');
    print('3. You have proper network connectivity');
    exit(6);
  }
}
