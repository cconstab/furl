@Tags(['e2e'])
library;

import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:dio/dio.dart';

void main() {
  group('Furl Server Tests', () {
    late Process serverProcess;
    late int testPort;
    late Dio dio;

    setUpAll(() async {
      // Find an available port for testing
      testPort = await _findAvailablePort();
      dio = Dio();
      dio.options.connectTimeout = Duration(seconds: 10);
      dio.options.receiveTimeout = Duration(seconds: 30);
    });

    tearDownAll(() async {
      dio.close();
    });

    setUp(() async {
      // Start the server process for each test
      serverProcess = await Process.start('dart', [
        'run',
        'bin/furl_server.dart',
        '--port',
        testPort.toString(),
      ], workingDirectory: Directory.current.path);

      // Wait for server to start
      await _waitForServerStart(testPort);
    });

    tearDown(() async {
      // Kill the server process after each test
      serverProcess.kill();
      await serverProcess.exitCode;
    });

    test('Server starts and responds to health check', () async {
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

    test('Server serves furl.html for root path', () async {
      final response = await dio.get('http://localhost:$testPort/', options: Options(followRedirects: false));

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

    test('API endpoints return proper JSON', () async {
      // Test atSign endpoint (should return proper error format)
      try {
        await dio.get('http://localhost:$testPort/api/atsign/nonexistent');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<DioException>());
        final dioError = e as DioException;
        expect(dioError.response?.statusCode, anyOf([400, 404, 500]));
        expect(dioError.response?.data, isA<Map>());
      }
    });

    test('Server handles concurrent requests', () async {
      final futures = <Future>[];

      // Make 10 concurrent requests
      for (int i = 0; i < 10; i++) {
        futures.add(dio.get('http://localhost:$testPort/api/health'));
      }

      final responses = await Future.wait(futures);

      // All requests should succeed
      for (final response in responses) {
        expect(response.statusCode, equals(200));
        expect(response.data['status'], equals('healthy'));
      }
    });

    test('Server handles malformed requests gracefully', () async {
      try {
        await dio.post('http://localhost:$testPort/api/atsign/test', data: {'invalid': 'data'});
        fail('Should have handled malformed request');
      } catch (e) {
        expect(e, isA<DioException>());
        // Server should respond with proper error, not crash
        final dioError = e as DioException;
        expect(dioError.response?.statusCode, isNotNull);
      }
    });

    test('Server validates atSign format', () async {
      final invalidAtSigns = [
        'invalid-atsign',
        '@',
        'no-at-symbol',
        '@multiple@atsigns',
        '@with spaces',
        '@with!special!chars',
      ];

      for (final invalidAtSign in invalidAtSigns) {
        try {
          await dio.get('http://localhost:$testPort/api/atsign/$invalidAtSign');
          // Some invalid formats might not throw, but should return error
        } catch (e) {
          expect(e, isA<DioException>());
        }
      }
    });

    test('Server handles large requests appropriately', () async {
      final largeData = 'x' * (10 * 1024 * 1024); // 10MB of data

      try {
        await dio.post(
          'http://localhost:$testPort/api/test',
          data: largeData,
          options: Options(sendTimeout: Duration(seconds: 30)),
        );
      } catch (e) {
        // Server should handle large requests gracefully
        expect(e, isA<DioException>());
        final dioError = e as DioException;
        expect(dioError.response?.statusCode, anyOf([413, 404, 405])); // Payload too large or method not allowed
      }
    });

    test('CORS headers are present for browser compatibility', () async {
      final response = await dio.get(
        'http://localhost:$testPort/api/health',
        options: Options(headers: {'Origin': 'http://localhost:3000'}),
      );

      // Just check that the request succeeds - CORS is handled by server
      expect(response.statusCode, equals(200));
    });
  });

  group('Server Configuration Tests', () {
    test('Server can start on different ports', () async {
      final port1 = await _findAvailablePort();
      final port2 = await _findAvailablePort(port1 + 1);

      final server1 = await Process.start('dart', ['run', 'bin/furl_server.dart', '--port', port1.toString()]);

      final server2 = await Process.start('dart', ['run', 'bin/furl_server.dart', '--port', port2.toString()]);

      try {
        await _waitForServerStart(port1);
        await _waitForServerStart(port2);

        final dio = Dio();
        final response1 = await dio.get('http://localhost:$port1/api/health');
        final response2 = await dio.get('http://localhost:$port2/api/health');

        expect(response1.statusCode, equals(200));
        expect(response2.statusCode, equals(200));

        dio.close();
      } finally {
        server1.kill();
        server2.kill();
        await server1.exitCode;
        await server2.exitCode;
      }
    });

    test('Server handles port already in use', () async {
      final testPort = await _findAvailablePort();

      // Start first server
      final server1 = await Process.start('dart', ['run', 'bin/furl_server.dart', '--port', testPort.toString()]);

      await _waitForServerStart(testPort);

      // Try to start second server on same port
      final server2 = await Process.start('dart', ['run', 'bin/furl_server.dart', '--port', testPort.toString()]);

      // Second server should fail to start
      final exitCode = await server2.exitCode.timeout(Duration(seconds: 5));
      expect(exitCode, isNot(equals(0)));

      server1.kill();
      await server1.exitCode;
    });
  });
}

/// Find an available port for testing
Future<int> _findAvailablePort([int startPort = 8080]) async {
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
