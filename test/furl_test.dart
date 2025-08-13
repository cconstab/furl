import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:random_string/random_string.dart';

void main() {
  group('Furl Security Tests', () {
    test('PIN generation produces 9-character alphanumeric strings', () {
      final pin = randomAlphaNumeric(9);
      expect(pin.length, equals(9));
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(pin), isTrue);
    });

    test('AES-256 encryption/decryption works correctly', () {
      // Test data
      final plaintext = 'This is a test file content for encryption testing.';
      final plaintextBytes = utf8.encode(plaintext);

      // Generate key and IV
      final key = encrypt.Key.fromSecureRandom(32); // 256-bit key
      final iv = encrypt.IV.fromSecureRandom(16); // 128-bit IV

      // Encrypt
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(plaintextBytes, iv: iv);

      // Decrypt
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      final decryptedText = utf8.decode(decrypted);

      expect(decryptedText, equals(plaintext));
    });

    test('PIN-based key derivation is consistent', () {
      final pin = 'TestPin12';
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final pinBytes = utf8.encode(pin);

      // Derive key twice
      final digest1 = sha256.convert(pinBytes + salt);
      final digest2 = sha256.convert(pinBytes + salt);

      expect(digest1.bytes, equals(digest2.bytes));
      expect(digest1.bytes.length, equals(32)); // SHA-256 produces 32-byte hash
    });

    test('Different PINs produce different derived keys', () {
      final pin1 = 'TestPin12';
      final pin2 = 'TestPin34';
      final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final pinBytes1 = utf8.encode(pin1);
      final pinBytes2 = utf8.encode(pin2);

      final digest1 = sha256.convert(pinBytes1 + salt);
      final digest2 = sha256.convert(pinBytes2 + salt);

      expect(digest1.bytes, isNot(equals(digest2.bytes)));
    });

    test('Different salts with same PIN produce different keys', () {
      final pin = 'TestPin12';
      final salt1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final salt2 = Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]);
      final pinBytes = utf8.encode(pin);

      final digest1 = sha256.convert(pinBytes + salt1);
      final digest2 = sha256.convert(pinBytes + salt2);

      expect(digest1.bytes, isNot(equals(digest2.bytes)));
    });
  });

  group('Furl Integration Tests', () {
    test('Full encryption workflow simulation', () {
      // Simulate the full encryption workflow
      final originalData = 'Secret file content that needs protection';
      final pin = randomAlphaNumeric(9);

      // Step 1: Generate AES key for file encryption
      final fileKey = encrypt.Key.fromSecureRandom(32);
      final fileIV = encrypt.IV.fromSecureRandom(16);

      // Step 2: Encrypt file
      final fileEncrypter = encrypt.Encrypter(encrypt.AES(fileKey, mode: encrypt.AESMode.cbc));
      final encryptedFile = fileEncrypter.encrypt(originalData, iv: fileIV);

      // Step 3: Generate salt and derive PIN key
      final salt = encrypt.IV.fromSecureRandom(8).bytes;
      final pinBytes = utf8.encode(pin);
      final digest = sha256.convert(pinBytes + salt);
      final pinKey = encrypt.Key(Uint8List.fromList(digest.bytes));

      // Step 4: Encrypt the file key with PIN-derived key
      final keyIV = encrypt.IV.fromSecureRandom(16);
      final keyEncrypter = encrypt.Encrypter(encrypt.AES(pinKey, mode: encrypt.AESMode.cbc));
      final encryptedFileKey = keyEncrypter.encryptBytes(fileKey.bytes, iv: keyIV);

      // Simulate decryption workflow
      // Step 5: Derive PIN key again (recipient side)
      final recoveredDigest = sha256.convert(pinBytes + salt);
      final recoveredPinKey = encrypt.Key(Uint8List.fromList(recoveredDigest.bytes));

      // Step 6: Decrypt the file key
      final recoveredKeyEncrypter = encrypt.Encrypter(encrypt.AES(recoveredPinKey, mode: encrypt.AESMode.cbc));
      final recoveredFileKeyBytes = recoveredKeyEncrypter.decryptBytes(encryptedFileKey, iv: keyIV);
      final recoveredFileKey = encrypt.Key(Uint8List.fromList(recoveredFileKeyBytes));

      // Step 7: Decrypt the file
      final recoveredFileEncrypter = encrypt.Encrypter(encrypt.AES(recoveredFileKey, mode: encrypt.AESMode.cbc));
      final decryptedData = recoveredFileEncrypter.decrypt(encryptedFile, iv: fileIV);

      expect(decryptedData, equals(originalData));
    });
  });
}
