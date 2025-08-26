@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

void main() {
  group('Basic Integration Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('furl_basic_test_');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('CLI basic syntax check', () async {
      // Test that CLI runs without crashing
      final result = await Process.run('dart', [
        'run',
        'bin/furl.dart',
      ], workingDirectory: Directory.current.path);

      // Should exit with error for missing arguments, but not crash
      expect(result.exitCode, isNot(equals(0)));
    });

    test('File hash calculation test', () async {
      final testFile = File('${tempDir.path}/hash_test.txt');
      final testContent = 'Content for hash test';
      await testFile.writeAsString(testContent);

      // Calculate expected hash
      final expectedHash = sha512.convert(utf8.encode(testContent)).toString();

      // Verify hash calculation
      final fileContents = await testFile.readAsBytes();
      final actualHash = sha512.convert(fileContents).toString();

      expect(actualHash, equals(expectedHash));
    });

    test('Binary file creation and validation', () async {
      // Create a binary test file
      final binaryFile = File('${tempDir.path}/binary_test.bin');
      final binaryData = Uint8List.fromList(List.generate(256, (i) => i));
      await binaryFile.writeAsBytes(binaryData);

      // Verify file was created correctly
      final readData = await binaryFile.readAsBytes();
      expect(readData.length, equals(256));
      expect(readData[0], equals(0));
      expect(readData[255], equals(255));
    });
  });

  group('Server API Tests', () {
    late Process serverProcess;
    late int testPort;
    late Dio dio;

    setUpAll(() async {
      testPort = await _findAvailablePort();
      dio = Dio();
      dio.options.connectTimeout = Duration(seconds: 5);
      dio.options.receiveTimeout = Duration(seconds: 10);
    });

    tearDownAll(() async {
      dio.close();
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

    test('Server health check works', () async {
      final response = await dio.get('http://localhost:$testPort/api/health');

      expect(response.statusCode, equals(200));
      expect(response.data, contains('status'));
      expect(response.data['status'], equals('healthy'));
    });

    test('Server serves static files', () async {
      final response = await dio.get('http://localhost:$testPort/furl.html');

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type']?.first, contains('text/html'));
      expect(response.data, contains('<html'));
    });

    test('Server handles 404 for non-existent files', () async {
      try {
        await dio.get('http://localhost:$testPort/nonexistent.html');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<DioException>());
        final dioError = e as DioException;
        expect(dioError.response?.statusCode, equals(404));
      }
    });
  });
}

/// Find an available port for testing
Future<int> _findAvailablePort([int startPort = 9080]) async {
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

/// Wait for server to start responding
Future<void> _waitForServerStart(int port) async {
  final dio = Dio();
  dio.options.connectTimeout = Duration(seconds: 1);

  for (int i = 0; i < 20; i++) {
    try {
      await dio.get('http://localhost:$port/api/health');
      dio.close();
      return;
    } catch (e) {
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  dio.close();
  throw Exception('Server failed to start on port $port');
}
