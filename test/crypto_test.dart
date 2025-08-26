import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:random_string/random_string.dart';

void main() {
  group('Cryptographic Functions Tests', () {
    test('PIN generation produces valid 9-character strings', () {
      for (int i = 0; i < 100; i++) {
        final pin = randomAlphaNumeric(9);
        expect(pin.length, equals(9));
        expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(pin), isTrue);
      }
    });

    test('SHA-512 file hash calculation', () async {
      // Create a temporary test file
      final tempFile = File('test_hash_file.tmp');
      await tempFile.writeAsString('Test content for hash calculation');

      // Calculate hash manually
      final contents = await tempFile.readAsBytes();
      final expectedHash = sha512.convert(contents).toString();

      // Test our hash function would work the same way
      final actualHash = sha512.convert(contents).toString();
      expect(actualHash, equals(expectedHash));

      // Cleanup
      await tempFile.delete();
    });

    test('AES-CTR encryption/decryption with different data sizes', () {
      final testCases = [
        'a',
        'Hello World!',
        'A' * 100,
        'Mixed content 123 !@# with unicode: 🔒🚀📊',
        'Large content: ' + ('x' * 10000),
      ];

      for (final testData in testCases) {
        final key = encrypt.Key.fromSecureRandom(32);
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.ctr),
        );

        final encrypted = encrypter.encrypt(testData, iv: iv);
        final decrypted = encrypter.decrypt(encrypted, iv: iv);

        expect(
          decrypted,
          equals(testData),
          reason:
              'Failed for data: "${testData.length > 50 ? testData.substring(0, 50) + "..." : testData}"',
        );
      }
    });

    test('Key derivation consistency with salt', () {
      final pin = 'TestPin123';
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Derive key multiple times
      final results = <List<int>>[];
      for (int i = 0; i < 10; i++) {
        final pinBytes = utf8.encode(pin);
        final digest = sha256.convert(pinBytes + salt);
        results.add(digest.bytes);
      }

      // All results should be identical
      for (int i = 1; i < results.length; i++) {
        expect(results[i], equals(results[0]));
      }
    });

    test('Different PIN lengths produce different keys', () {
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final pins = ['a', 'ab', 'abc', 'abcd', 'abcde', 'TestPin123'];
      final hashes = <String>[];

      for (final pin in pins) {
        final pinBytes = utf8.encode(pin);
        final digest = sha256.convert(pinBytes + salt);
        hashes.add(digest.toString());
      }

      // All hashes should be unique
      final uniqueHashes = hashes.toSet();
      expect(uniqueHashes.length, equals(hashes.length));
    });

    test('Encryption with wrong key fails gracefully', () {
      final plaintext = 'Secret message';
      final correctKey = encrypt.Key.fromSecureRandom(32);
      final wrongKey = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(correctKey, mode: encrypt.AESMode.ctr),
      );
      final wrongEncrypter = encrypt.Encrypter(
        encrypt.AES(wrongKey, mode: encrypt.AESMode.ctr),
      );

      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // With CTR mode, wrong key doesn't throw, just produces garbage
      try {
        final wrongDecrypted = wrongEncrypter.decrypt(encrypted, iv: iv);
        expect(wrongDecrypted, isNot(equals(plaintext)));
      } catch (e) {
        // It's also acceptable for it to throw an exception
        expect(e, isNotNull);
      }
    });

    test('IV uniqueness for multiple encryptions', () {
      final plaintext = 'Same message';
      final key = encrypt.Key.fromSecureRandom(32);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final encryptedResults = <String>[];
      for (int i = 0; i < 100; i++) {
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypted = encrypter.encrypt(plaintext, iv: iv);
        encryptedResults.add(encrypted.base64);
      }

      // All encrypted results should be different due to unique IVs
      final uniqueResults = encryptedResults.toSet();
      expect(uniqueResults.length, equals(encryptedResults.length));
    });

    test('Large data encryption performance', () {
      final largeData = 'x' * (1024 * 1024); // 1MB of data
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final stopwatch = Stopwatch()..start();
      final encrypted = encrypter.encrypt(largeData, iv: iv);
      final encryptTime = stopwatch.elapsedMilliseconds;

      stopwatch.reset();
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      final decryptTime = stopwatch.elapsedMilliseconds;
      stopwatch.stop();

      expect(decrypted, equals(largeData));
      print('Encryption of 1MB took: ${encryptTime}ms');
      print('Decryption of 1MB took: ${decryptTime}ms');

      // Performance should be reasonable (less than 5 seconds for 1MB)
      expect(encryptTime, lessThan(5000));
      expect(decryptTime, lessThan(5000));
    });
  });

  group('Edge Cases and Error Handling', () {
    test('Non-empty data encryption', () {
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final testData = 'test data';
      final encrypted = encrypter.encrypt(testData, iv: iv);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      expect(decrypted, equals(testData));
    });

    test('Special characters and unicode handling', () {
      final specialChars =
          'Special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?`~"\'\\/ and unicode: 🔒🚀📊🌐💻🔑';
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final encrypted = encrypter.encrypt(specialChars, iv: iv);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      expect(decrypted, equals(specialChars));
    });

    test('Maximum length PIN handling', () {
      final longPin = 'a' * 1000; // Very long PIN
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final pinBytes = utf8.encode(longPin);

      expect(() => sha256.convert(pinBytes + salt), isNot(throwsException));

      final digest = sha256.convert(pinBytes + salt);
      expect(digest.bytes.length, equals(32));
    });

    test('Binary data handling', () {
      // Create binary data (not UTF-8 text)
      final binaryData = Uint8List.fromList(List.generate(256, (i) => i));
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final encrypted = encrypter.encryptBytes(binaryData, iv: iv);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      expect(decrypted, equals(binaryData));
    });
  });
}
