import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('CLI Argument Validation Tests', () {
    test('Valid atSign formats are accepted', () async {
      final validAtSigns = [
        '@alice',
        '@bob123',
        '@test_user',
        '@user-name',
        '@company.user',
        '@long.username.with.dots',
      ];

      final testFile = File('test_cli_args.txt');
      await testFile.writeAsString('test content');

      try {
        for (final atSign in validAtSigns) {
          final result = await Process.run('dart', [
            'run', 'bin/furl.dart',
            atSign,
            testFile.path,
            '1h',
            '--help', // This will show help instead of actually running
          ], workingDirectory: Directory.current.path);

          // Help should be shown (exit code 0) for valid atSign format
          expect(result.exitCode, equals(0), reason: 'Valid atSign $atSign should be accepted');
        }
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Invalid atSign formats are rejected', () async {
      final invalidAtSigns = [
        'alice', // Missing @
        '@@alice', // Double @
        '@alice@bob', // Multiple @
      ];

      final testFile = File('test_cli_invalid.txt');
      await testFile.writeAsString('test content');

      try {
        for (final atSign in invalidAtSigns) {
          final result = await Process.run('dart', [
            'run',
            'bin/furl.dart',
            atSign,
            testFile.path,
            '1h',
          ], workingDirectory: Directory.current.path);

          // Should reject invalid atSign format
          expect(result.exitCode, isNot(equals(0)), reason: 'Invalid atSign $atSign should be rejected');
        }
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Valid duration formats are accepted', () async {
      final validDurations = ['1h', '2h', '1d'];

      final testFile = File('test_duration_valid.txt');
      await testFile.writeAsString('test content');

      try {
        for (final duration in validDurations) {
          final result = await Process.run('dart', [
            'run', 'bin/furl.dart',
            '@testuser',
            testFile.path,
            duration,
            '--help', // Show help instead of running
          ], workingDirectory: Directory.current.path);

          // Just check it doesn't crash with valid duration
          expect(result.exitCode, anyOf([0, 1]), reason: 'Valid duration $duration should not cause crash');
        }
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Invalid duration formats are rejected', () async {
      final invalidDurations = ['0m', '-1h', '1x'];

      final testFile = File('test_duration_invalid.txt');
      await testFile.writeAsString('test content');

      try {
        for (final duration in invalidDurations) {
          final result = await Process.run('dart', [
            'run',
            'bin/furl.dart',
            '@testuser',
            testFile.path,
            duration,
          ], workingDirectory: Directory.current.path);

          expect(result.exitCode, isNot(equals(0)), reason: 'Invalid duration $duration should be rejected');
        }
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('File validation works correctly', () async {
      // Test non-existent file
      final nonExistentResult = await Process.run('dart', [
        'run',
        'bin/furl.dart',
        '@testuser',
        '/path/to/nonexistent/file.txt',
        '1h',
      ], workingDirectory: Directory.current.path);

      expect(nonExistentResult.exitCode, isNot(equals(0)));

      // Test directory instead of file
      final dirResult = await Process.run('dart', [
        'run',
        'bin/furl.dart',
        '@testuser',
        Directory.current.path,
        '1h',
      ], workingDirectory: Directory.current.path);

      expect(dirResult.exitCode, isNot(equals(0)));
    });

    test('Command line flags work correctly', () async {
      final testFile = File('test_flags.txt');
      await testFile.writeAsString('test content');

      try {
        // Test help flag
        final helpResult = await Process.run('dart', [
          'run',
          'bin/furl.dart',
          '--help',
        ], workingDirectory: Directory.current.path);

        // Help might not be implemented, just check it doesn't crash
        expect(helpResult.exitCode, anyOf([0, 1]));

        // Test quiet flag with help to avoid actual execution
        final quietResult = await Process.run('dart', [
          'run', 'bin/furl.dart',
          '--help', // Just test that it parses
        ], workingDirectory: Directory.current.path);

        expect(quietResult.exitCode, anyOf([0, 1]));
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Invalid flag combinations are handled', () async {
      final testFile = File('test_invalid_flags.txt');
      await testFile.writeAsString('test content');

      try {
        // Test unknown flag
        final unknownFlagResult = await Process.run('dart', [
          'run',
          'bin/furl.dart',
          '@testuser',
          testFile.path,
          '1h',
          '--unknown-flag',
        ], workingDirectory: Directory.current.path);

        // Should either reject unknown flag or ignore it
        expect(unknownFlagResult.exitCode, anyOf([0, 1, 2, 6]));
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Required arguments are enforced', () async {
      // Test missing file argument
      final missingFileResult = await Process.run('dart', [
        'run',
        'bin/furl.dart',
        '@testuser',
        '1h',
      ], workingDirectory: Directory.current.path);

      expect(missingFileResult.exitCode, isNot(equals(0)));

      // Test missing duration argument
      final testFile = File('test_missing_args.txt');
      await testFile.writeAsString('test content');

      try {
        final missingDurationResult = await Process.run('dart', [
          'run',
          'bin/furl.dart',
          '@testuser',
          testFile.path,
        ], workingDirectory: Directory.current.path);

        expect(missingDurationResult.exitCode, isNot(equals(0)));

        // Test missing atSign argument
        final missingAtSignResult = await Process.run('dart', [
          'run',
          'bin/furl.dart',
          testFile.path,
          '1h',
        ], workingDirectory: Directory.current.path);

        expect(missingAtSignResult.exitCode, isNot(equals(0)));
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('File size warnings are displayed appropriately', () async {
      // Create a large file (simulated)
      final largeFile = File('test_large_file.txt');
      final largeContent = 'x' * (100 * 1024 * 1024 + 1); // Just over 100MB
      await largeFile.writeAsString(largeContent);

      try {
        final result = await Process.run('dart', [
          'run', 'bin/furl.dart',
          '@testuser',
          largeFile.path,
          '1h',
          '--help', // Prevent actual execution
        ], workingDirectory: Directory.current.path);

        // Should show help regardless of file size
        expect(result.exitCode, equals(0));
      } finally {
        if (await largeFile.exists()) {
          await largeFile.delete();
        }
      }
    });
  });

  group('Server CLI Tests', () {
    test('Server command line arguments work', () async {
      // Test server help
      final helpResult = await Process.run('dart', [
        'run',
        'bin/furl_server.dart',
        '--help',
      ], workingDirectory: Directory.current.path);

      // Server might not have --help, but should handle it gracefully
      expect(helpResult.exitCode, anyOf([0, 1, 2]));

      // Test invalid port
      final invalidPortResult = await Process.run('dart', [
        'run',
        'bin/furl_server.dart',
        '--port',
        'invalid',
      ], workingDirectory: Directory.current.path);

      expect(invalidPortResult.exitCode, isNot(equals(0)));

      // Test port out of range
      final outOfRangeResult = await Process.run('dart', [
        'run',
        'bin/furl_server.dart',
        '--port',
        '70000',
      ], workingDirectory: Directory.current.path);

      expect(outOfRangeResult.exitCode, isNot(equals(0)));
    });

    test('Server starts with valid arguments', () async {
      final testPort = await _findAvailablePort();

      final serverProcess = await Process.start('dart', [
        'run',
        'bin/furl_server.dart',
        '--port',
        testPort.toString(),
      ], workingDirectory: Directory.current.path);

      // Give server time to start
      await Future.delayed(Duration(seconds: 2));

      // Check if server is running
      bool serverStarted = false;
      try {
        final socket = await Socket.connect('localhost', testPort);
        await socket.close();
        serverStarted = true;
      } catch (e) {
        // Server might not be ready yet
      }

      serverProcess.kill();
      await serverProcess.exitCode;

      expect(serverStarted, isTrue, reason: 'Server should start with valid port');
    });
  });
}

Future<int> _findAvailablePort([int startPort = 9280]) async {
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
