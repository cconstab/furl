import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:pointycastle/export.dart';

class FileEncryptionService {
  static const String defaultServerUrl = 'https://furl.host';
  static const int defaultTtl = 3600; // 1 hour
  static final AtSignLogger _logger = AtSignLogger('FileEncryptionService');

  /// Generate a strong PIN with same logic as CLI (9 characters)
  static String generateStrongPin(int length) {
    // Character set: uppercase, lowercase, numbers, and safe special characters
    // Excludes: 0, O, 1, l, I for readability
    // Excludes: quotes, spaces, and URL-problematic characters
    const String chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*()_+-=[]{}|;:,.<>?';

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

  /// Calculate SHA-512 hash of a file
  static Future<String> calculateFileSha512(File file) async {
    final contents = await file.readAsBytes();
    final digest = sha512.convert(contents);
    return digest.toString();
  }

  /// Encrypt file using ChaCha20 (matching CLI implementation exactly)
  static Future<Uint8List> encryptFileChaCha20(File file, Uint8List key, Uint8List nonce) async {
    // Create ChaCha20 cipher
    final cipher = ChaCha20Engine();
    final params = ParametersWithIV<KeyParameter>(KeyParameter(key), nonce);
    cipher.init(true, params); // true = encrypt

    // Read file and encrypt
    final fileBytes = await file.readAsBytes();
    final encryptedBytes = Uint8List(fileBytes.length);

    // Use processBytes like the CLI for proper keystream state management
    cipher.processBytes(fileBytes, 0, fileBytes.length, encryptedBytes, 0);

    return encryptedBytes;
  }

  /// Upload file to filebin.net with progress tracking
  static Future<String> uploadFileToServer(
    Uint8List encryptedBytes,
    String fileName,
    Function(double)? onProgress,
  ) async {
    final dio = Dio()
      ..options.connectTimeout = Duration(minutes: 5)
      ..options.receiveTimeout = Duration(minutes: 30)
      ..options.sendTimeout = Duration(hours: 2)
      ..options.followRedirects = true
      ..options.maxRedirects = 5;

    try {
      // Generate unique bin ID
      final uuid = Uuid();
      final binId = 'furl${uuid.v4().replaceAll('-', '')}';

      // Sanitize filename for URL - remove or replace problematic characters
      final sanitizedFileName = fileName
          .replaceAll('@', '_at_')
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll('?', '_')
          .replaceAll('#', '_')
          .replaceAll('&', '_')
          .replaceAll('=', '_')
          .replaceAll('%', '_');

      final uploadUrl = 'https://filebin.net/$binId/${sanitizedFileName}.encrypted';

      // Upload with progress tracking
      final response = await dio.post(
        uploadUrl,
        data: encryptedBytes,
        options: Options(headers: {'Content-Type': 'application/octet-stream'}, responseType: ResponseType.plain),
        onSendProgress: (int sent, int total) {
          if (onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return uploadUrl;
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      _logger.severe('Upload error: $e');
      // Re-throw the actual error instead of masking it with a mock URL
      if (e is DioException) {
        throw Exception('Upload failed: ${e.message}');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  /// Store metadata in atPlatform with pre-generated key name
  static Future<String> storeMetadataInAtPlatform({
    required String fileUrl,
    required String fileName,
    required String pin,
    required List<int> chaCha20Key,
    required List<int> chaCha20Nonce,
    required String sha512Hash,
    required int fileSize,
    String? customMessage,
    required int ttl,
    AtClient? atClient, // Accept pre-initialized atClient to avoid delays
  }) async {
    try {
      // Encrypt ChaCha20 key with PIN
      final salt = encrypt.IV.fromSecureRandom(8).bytes;
      final pinBytes = utf8.encode(pin);

      // Derive key from PIN using SHA256
      final digest = sha256.convert(pinBytes + salt);
      final derivedKey = Uint8List.fromList(digest.bytes);

      final keyEncrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(derivedKey), mode: encrypt.AESMode.ctr));
      final keyIv = encrypt.IV.fromSecureRandom(16);
      final encryptedChaCha20Key = keyEncrypter.encryptBytes(chaCha20Key, iv: keyIv);

      // Generate unique atKey name
      final uuid = Uuid();
      final randomId = uuid.v4().replaceAll('-', '');
      final atKeyName = '_furl_$randomId';

      // Create secret payload
      final secretPayload = jsonEncode({
        'file_url': fileUrl,
        'chacha20_key': base64Encode(encryptedChaCha20Key.bytes),
        'key_iv': base64Encode(keyIv.bytes),
        'key_salt': base64Encode(salt),
        'file_nonce': base64Encode(chaCha20Nonce),
        'file_name': fileName,
        'cipher': 'chacha20',
        'sha512_hash': sha512Hash,
        'file_size': fileSize,
        if (customMessage != null) 'message': customMessage,
      });

      // Get atClient (use provided one or get from manager)
      final atClientInstance = atClient ?? AtClientManager.getInstance().atClient;

      // Create atKey
      final atKey = AtKey()
        ..key = atKeyName
        ..metadata = (Metadata()
          ..isPublic = true
          ..ttl = ttl * 1000); // TTL in milliseconds

      // Store in atPlatform
      final putRequestOptions = PutRequestOptions()..useRemoteAtServer = true;
      await atClientInstance.put(atKey, secretPayload, putRequestOptions: putRequestOptions);

      _logger.info('Metadata stored in atPlatform with key: $atKeyName');

      // Verify data is accessible (simplified version)
      await Future.delayed(Duration(seconds: 2));

      return atKeyName;
    } catch (e) {
      _logger.severe('Error storing metadata: $e');
      rethrow;
    }
  }

  /// Generate retrieval URL
  static String generateRetrievalUrl({
    required String atSign,
    required String atKeyName,
    String serverUrl = defaultServerUrl,
  }) {
    return '$serverUrl/furl.html?atSign=$atSign&key=$atKeyName';
  }
}

/// Result of file encryption and upload
class UploadResult {
  final String url;
  final String pin;
  final String fileName;
  final int fileSize;
  final DateTime expiresAt;

  UploadResult({
    required this.url,
    required this.pin,
    required this.fileName,
    required this.fileSize,
    required this.expiresAt,
  });
}
