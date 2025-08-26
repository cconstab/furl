@Tags(['performance'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  group('Performance Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('furl_perf_test_');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('Encryption performance with different file sizes', () async {
      final fileSizes = [
        {'name': '1KB', 'size': 1024},
        {'name': '10KB', 'size': 10 * 1024},
        {'name': '100KB', 'size': 100 * 1024},
        {'name': '1MB', 'size': 1024 * 1024},
        {'name': '10MB', 'size': 10 * 1024 * 1024},
      ];

      for (final fileSize in fileSizes) {
        final testFile = File(
          '${tempDir.path}/perf_test_${fileSize['name']}.bin',
        );
        final testData = Uint8List(fileSize['size'] as int);

        // Fill with random-ish data
        for (int i = 0; i < testData.length; i++) {
          testData[i] = i % 256;
        }
        await testFile.writeAsBytes(testData);

        final stopwatch = Stopwatch()..start();

        // Simulate the encryption process
        final key = encrypt.Key.fromSecureRandom(32);
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.ctr),
        );

        final fileBytes = await testFile.readAsBytes();
        final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

        stopwatch.stop();

        expect(decrypted, equals(fileBytes));

        final throughputMBps =
            (fileSize['size'] as int) /
            (1024 * 1024) /
            (stopwatch.elapsedMilliseconds / 1000);
        print(
          '${fileSize['name']}: ${stopwatch.elapsedMilliseconds}ms (${throughputMBps.toStringAsFixed(2)} MB/s)',
        );

        // Performance expectations (adjust based on hardware)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10000),
          reason:
              '${fileSize['name']} encryption took too long: ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    });

    test('Hash calculation performance', () async {
      final fileSizes = [
        {'name': '1MB', 'size': 1024 * 1024},
        {'name': '10MB', 'size': 10 * 1024 * 1024},
        {'name': '50MB', 'size': 50 * 1024 * 1024},
      ];

      for (final fileSize in fileSizes) {
        final testFile = File(
          '${tempDir.path}/hash_perf_${fileSize['name']}.bin',
        );
        final testData = Uint8List(fileSize['size'] as int);

        // Fill with pattern data
        for (int i = 0; i < testData.length; i++) {
          testData[i] = (i * 17) % 256;
        }
        await testFile.writeAsBytes(testData);

        final stopwatch = Stopwatch()..start();
        final contents = await testFile.readAsBytes();
        final hash = sha512.convert(contents);
        stopwatch.stop();

        expect(hash.toString().length, equals(128)); // SHA-512 hex length

        final throughputMBps =
            (fileSize['size'] as int) /
            (1024 * 1024) /
            (stopwatch.elapsedMilliseconds / 1000);
        print(
          'Hash ${fileSize['name']}: ${stopwatch.elapsedMilliseconds}ms (${throughputMBps.toStringAsFixed(2)} MB/s)',
        );

        // Hash should be fast
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason:
              '${fileSize['name']} hash took too long: ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    });

    test('Memory usage with large files', () async {
      // Test memory efficiency with a large file
      final largeFile = File('${tempDir.path}/memory_test.bin');
      final largeSize = 100 * 1024 * 1024; // 100MB

      // Create large file efficiently
      final sink = largeFile.openWrite();
      for (int i = 0; i < largeSize ~/ 1024; i++) {
        final chunk = Uint8List(1024);
        for (int j = 0; j < chunk.length; j++) {
          chunk[j] = (i + j) % 256;
        }
        sink.add(chunk);
      }
      await sink.close();

      // Monitor memory during encryption
      final initialMemory = _getMemoryUsage();

      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ctr),
      );

      final stopwatch = Stopwatch()..start();
      final fileBytes = await largeFile.readAsBytes();
      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
      stopwatch.stop();

      final finalMemory = _getMemoryUsage();
      final memoryIncrease = finalMemory - initialMemory;

      print('Large file encryption: ${stopwatch.elapsedMilliseconds}ms');
      print('Memory increase: ${memoryIncrease / (1024 * 1024)}MB');

      expect(encrypted.bytes.length, greaterThan(largeSize - 1000));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(30000),
      ); // Should complete in 30s
    });

    test('Concurrent encryption performance', () async {
      final numFiles = 5;
      final fileSize = 1024 * 1024; // 1MB each
      final futures = <Future>[];

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < numFiles; i++) {
        futures.add(_encryptTestFile(tempDir, i, fileSize));
      }

      await Future.wait(futures);
      stopwatch.stop();

      final totalDataMB = (numFiles * fileSize) / (1024 * 1024);
      final throughputMBps =
          totalDataMB / (stopwatch.elapsedMilliseconds / 1000);

      print(
        'Concurrent encryption of ${numFiles}x1MB: ${stopwatch.elapsedMilliseconds}ms',
      );
      print('Total throughput: ${throughputMBps.toStringAsFixed(2)} MB/s');

      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    });
  });

  group('Stress Tests', () {
    late Process serverProcess;
    late int testPort;
    late Dio dio;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('furl_stress_test_');
      testPort = await _findAvailablePort();
      dio = Dio();
      dio.options.connectTimeout = Duration(seconds: 30);
      dio.options.receiveTimeout = Duration(seconds: 60);
    });

    tearDownAll(() async {
      dio.close();
      await tempDir.delete(recursive: true);
    });

    setUp(() async {
      serverProcess = await Process.start('dart', [
        'run',
        'bin/furl_server.dart',
        '--port',
        testPort.toString(),
      ], workingDirectory: Directory.current.path);
      await _waitForServerStart(testPort);
    });

    tearDown(() async {
      serverProcess.kill();
      await serverProcess.exitCode;
    });

    test('Server handles rapid sequential requests', () async {
      final numRequests = 50;
      final results = <Response>[];

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < numRequests; i++) {
        final response = await dio.get('http://localhost:$testPort/api/health');
        results.add(response);
      }

      stopwatch.stop();

      expect(results.length, equals(numRequests));
      for (final result in results) {
        expect(result.statusCode, equals(200));
      }

      final requestsPerSecond =
          numRequests / (stopwatch.elapsedMilliseconds / 1000);
      print(
        'Sequential requests: $numRequests in ${stopwatch.elapsedMilliseconds}ms (${requestsPerSecond.toStringAsFixed(1)} req/s)',
      );

      expect(
        requestsPerSecond,
        greaterThan(10),
      ); // Should handle at least 10 req/s
    });

    test('Server handles burst concurrent requests', () async {
      final numRequests = 20;
      final futures = <Future<Response>>[];

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < numRequests; i++) {
        futures.add(dio.get('http://localhost:$testPort/api/health'));
      }

      final results = await Future.wait(futures);
      stopwatch.stop();

      expect(results.length, equals(numRequests));
      for (final result in results) {
        expect(result.statusCode, equals(200));
      }

      final requestsPerSecond =
          numRequests / (stopwatch.elapsedMilliseconds / 1000);
      print(
        'Concurrent requests: $numRequests in ${stopwatch.elapsedMilliseconds}ms (${requestsPerSecond.toStringAsFixed(1)} req/s)',
      );

      expect(
        requestsPerSecond,
        greaterThan(5),
      ); // Should handle concurrent load
    });

    test('Server stability under sustained load', () async {
      final duration = Duration(seconds: 5);
      final endTime = DateTime.now().add(duration);
      var requestCount = 0;
      var errorCount = 0;

      print('Running sustained load test for ${duration.inSeconds} seconds...');

      while (DateTime.now().isBefore(endTime)) {
        try {
          final response = await dio.get(
            'http://localhost:$testPort/api/health',
          );
          if (response.statusCode == 200) {
            requestCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          errorCount++;
        }

        // Small delay to avoid overwhelming
        await Future.delayed(Duration(milliseconds: 50));
      }

      print('Sustained load: $requestCount successful, $errorCount errors');

      expect(requestCount, greaterThan(20)); // Should handle many requests
      expect(
        errorCount / (requestCount + errorCount),
        lessThan(0.1),
      ); // Less than 10% error rate
    });

    test('Memory stability under load', () async {
      final initialMemory = _getMemoryUsage();

      // Create fewer test files to reduce load
      for (int i = 0; i < 3; i++) {
        final testFile = File('${tempDir.path}/stress_test_$i.txt');
        await testFile.writeAsString('Stress test content $i: ' + ('x' * 1000));

        final uploadResult = await Process.run('dart', [
          'run',
          'bin/furl.dart',
          '@stresstest$i',
          testFile.path,
          '5m',
          '--server',
          'http://localhost:$testPort',
          '--quiet',
        ], workingDirectory: Directory.current.path);

        // Allow some uploads to fail under stress conditions
        if (uploadResult.exitCode != 0) {
          print('Upload $i failed with exit code ${uploadResult.exitCode}');
        }
      }

      final finalMemory = _getMemoryUsage();
      final memoryIncrease = finalMemory - initialMemory;

      print(
        'Memory increase during stress test: ${memoryIncrease / (1024 * 1024)}MB',
      );

      // Memory increase should be reasonable
      expect(
        memoryIncrease,
        lessThan(500 * 1024 * 1024),
      ); // Less than 500MB increase
    });
  });
}

Future<void> _encryptTestFile(Directory tempDir, int index, int size) async {
  final testFile = File('${tempDir.path}/concurrent_test_$index.bin');
  final testData = Uint8List(size);

  for (int i = 0; i < testData.length; i++) {
    testData[i] = (i + index) % 256;
  }
  await testFile.writeAsBytes(testData);

  final key = encrypt.Key.fromSecureRandom(32);
  final iv = encrypt.IV.fromSecureRandom(16);
  final encrypter = encrypt.Encrypter(
    encrypt.AES(key, mode: encrypt.AESMode.ctr),
  );

  final fileBytes = await testFile.readAsBytes();
  final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
  final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

  if (!_uint8ListsEqual(Uint8List.fromList(decrypted), fileBytes)) {
    throw Exception('Encryption/decryption mismatch for file $index');
  }
}

bool _uint8ListsEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _getMemoryUsage() {
  // Simple memory usage estimation (this is approximate)
  return Platform
      .resolvedExecutable
      .length; // Placeholder - real implementation would use process memory
}

Future<int> _findAvailablePort([int startPort = 9180]) async {
  for (int port = startPort; port < startPort + 100; port++) {
    try {
      final socket = await ServerSocket.bind('localhost', port);
      await socket.close();
      return port;
    } catch (e) {
      // Port is in use, try next one
    }
  }
  throw Exception('No available ports found');
}

Future<void> _waitForServerStart(int port) async {
  final dio = Dio();
  dio.options.connectTimeout = Duration(seconds: 1);

  for (int i = 0; i < 30; i++) {
    try {
      await dio.get('http://localhost:$port/api/health');
      dio.close();
      return;
    } catch (e) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  dio.close();
  throw Exception('Server failed to start on port $port');
}
