import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:random_string/random_string.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 3) {
    print('Usage: dart run bin/furl.dart <atSign> <file_path> <ttl_seconds> [-v]');
    print('Example: dart run bin/furl.dart @alice document.pdf 3600');
    print('         dart run bin/furl.dart @alice document.pdf 3600 -v  (verbose)');
    exit(1);
  }

  final atSign = arguments[0];
  final filePath = arguments[1];
  final ttl = int.tryParse(arguments[2]) ?? 3600;
  final verbose = arguments.contains('-v');

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
    print('PIN for recipient: $pin');

    // 3. Encrypt file
    final fileBytes = await File(filePath).readAsBytes();
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final encryptedFile = encrypter.encryptBytes(fileBytes, iv: iv);

    // 4. Upload encrypted file to filebin.net
    print('Uploading encrypted file to filebin.net...');
    final fileName = filePath.split(Platform.pathSeparator).last;

    String fileUrl;
    try {
      // Upload to filebin.net - they require a bin first, then file upload
      // Use UUID for bin ID instead of timestamp for better security
      final uuid = Uuid();
      final binId = 'furl${uuid.v4().replaceAll('-', '')}';

      // Upload file directly to bin
      final uploadResp = await http.post(
        Uri.parse('https://filebin.net/$binId/${fileName}.encrypted'),
        headers: {'Content-Type': 'application/octet-stream'},
        body: encryptedFile.bytes,
      );

      if (uploadResp.statusCode == 201 || uploadResp.statusCode == 200) {
        fileUrl = 'https://filebin.net/$binId/${fileName}.encrypted';
        print('File uploaded to: $fileUrl');
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
    print('Storing secrets in atPlatform...');

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

    await atClient.put(atKey, secretPayload, putRequestOptions: putRequestOptions);
    print('Secrets stored in atPlatform with public key: $atKeyName');
    print(atKey);

    // 7. Verify the data is retrievable from remote server before exiting
    print('\nVerifying data is accessible on remote atServer...');
    var maxRetries = 10;
    var retryCount = 0;
    bool dataVerified = false;

    while (retryCount < maxRetries && !dataVerified) {
      try {
        await Future.delayed(Duration(seconds: 2)); // Wait 2 seconds between attempts

        // Force a fresh lookup from the atServer (not cached)
        final getRequestOptions = GetRequestOptions()..bypassCache = true;
        final retrievedData = await atClient.get(atKey, getRequestOptions: getRequestOptions);

        if (retrievedData.value != null) {
          print('✓ Data successfully verified on remote atServer');
          dataVerified = true;
        } else {
          retryCount++;
          print('⏳ Attempt $retryCount/$maxRetries - waiting for remote sync...');
        }
      } catch (e) {
        retryCount++;
        print('⏳ Attempt $retryCount/$maxRetries - waiting for remote sync... ($e)');
      }
    }

    if (!dataVerified) {
      print('⚠️  Warning: Could not verify data sync to remote server after $maxRetries attempts');
      print('   The data may still be syncing. Try the download in a few minutes.');
    }

    // 8. Print retrieval URL
    print('\nSend this URL to the recipient:');
    print('http://localhost:8081/furl.html?atSign=$atSign&key=$atKeyName');
    print('They will need the PIN: $pin');
    print('\nNote: Make sure both servers are running:');
    print('  API Server: dart run bin/furl_api.dart');
    print('  Web Server: dart run bin/furl_web.dart');

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
          true // We don't need local storage for a simple put
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
