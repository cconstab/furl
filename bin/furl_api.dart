import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Simple web API server to resolve atSign to FQDN:PORT
/// This queries the atDirectory at root.atsign.org:64 to get the atServer details
class FurlApiServer {
  static const String atDirectoryHost = 'root.atsign.org';
  static const int atDirectoryPort = 64;

  HttpServer? _server;

  Future<void> start({int port = 8080}) async {
    _server = await HttpServer.bind('localhost', port);
    print('Furl API Server started on http://localhost:$port');
    print('Endpoints:');
    print('  GET /atsign/{atSign} - Get FQDN:PORT for an atSign');
    print('  GET /fetch/{atSign}/{keyName} - Fetch public atKey data (CORS proxy)');
    print('  GET /download?url={url} - Proxy file download (CORS proxy)');
    print('  GET /health - Health check');

    await for (HttpRequest request in _server!) {
      await _handleRequest(request);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for web access
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    try {
      final uri = request.uri;

      if (request.method == 'OPTIONS') {
        // Handle preflight CORS requests
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      if (uri.path == '/health') {
        await _handleHealth(request);
      } else if (uri.path == '/download' && uri.queryParameters.containsKey('url')) {
        final fileUrl = uri.queryParameters['url']!;
        await _handleFileDownload(request, fileUrl);
      } else if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'atsign') {
        final atSign = uri.pathSegments[1];
        await _handleAtSignLookup(request, atSign);
      } else if (uri.pathSegments.length == 3 && uri.pathSegments[0] == 'fetch') {
        final atSign = uri.pathSegments[1];
        final keyName = uri.pathSegments[2];
        await _handleFetchData(request, atSign, keyName);
      } else {
        await _handle404(request);
      }
    } catch (e) {
      await _handleError(request, e);
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'status': 'healthy', 'timestamp': DateTime.now().toIso8601String(), 'service': 'furl-api'}),
    );
    await request.response.close();
  }

  Future<void> _handleAtSignLookup(HttpRequest request, String atSign) async {
    try {
      // Ensure atSign starts with @
      final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';
      // But send to atDirectory without the @
      final lookupAtSign = normalizedAtSign.substring(1);

      print('Looking up atServer details for: $normalizedAtSign (sending: $lookupAtSign)');

      // Query the atDirectory to get the atServer details
      final atServerInfo = await _queryAtDirectory(lookupAtSign);

      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'atSign': normalizedAtSign,
          'host': atServerInfo['host'],
          'port': atServerInfo['port'],
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Error looking up $atSign: $e');
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': 'AtSign not found or atDirectory unreachable',
          'atSign': atSign,
          'details': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    }
    await request.response.close();
  }

  Future<void> _handleFetchData(HttpRequest request, String atSign, String keyName) async {
    try {
      // Ensure atSign starts with @
      final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

      print('Fetching data for: $normalizedAtSign, key: $keyName');

      // First get the atServer details
      final lookupAtSign = normalizedAtSign.substring(1);
      final atServerInfo = await _queryAtDirectory(lookupAtSign);
      final host = atServerInfo['host'];
      final port = atServerInfo['port'];

      // Fetch the data from the atServer using curl (since it works reliably)
      final atServerUrl = 'https://$host:$port/public:$keyName.furl$normalizedAtSign';
      print('Fetching from atServer: $atServerUrl');

      // Use curl to fetch the data since it handles SSL properly
      final result = await Process.run('curl', ['-s', atServerUrl]);

      if (result.exitCode == 0) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;

        // Remove "data:" prefix if present
        String responseBody = result.stdout.toString().trim();
        if (responseBody.startsWith('data:')) {
          responseBody = responseBody.substring(5);
        }

        print('Response body after removing data: prefix: $responseBody');
        request.response.write(responseBody);
      } else {
        throw Exception('Curl failed with exit code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      print('Error fetching data for $atSign/$keyName: $e');
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': 'Could not fetch data from atServer',
          'atSign': atSign,
          'keyName': keyName,
          'details': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    }
    await request.response.close();
  }

  Future<void> _handleFileDownload(HttpRequest request, String fileUrl) async {
    try {
      print('Proxying file download: $fileUrl');

      // Use curl to download the file as binary data
      final result = await Process.run('curl', ['-s', '-L', fileUrl], stdoutEncoding: null);

      if (result.exitCode == 0) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.binary;
        // result.stdout is now List<int> when stdoutEncoding is null
        request.response.add(result.stdout as List<int>);
      } else {
        throw Exception('Curl failed with exit code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      print('Error downloading file from $fileUrl: $e');
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': 'Could not download file',
          'url': fileUrl,
          'details': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    }
    await request.response.close();
  }

  Future<Map<String, dynamic>> _queryAtDirectory(String atSign) async {
    Socket? socket;
    try {
      print('Connecting to atDirectory at $atDirectoryHost:$atDirectoryPort');

      // Connect to atDirectory using TLS
      socket = await SecureSocket.connect(atDirectoryHost, atDirectoryPort).timeout(Duration(seconds: 10));

      // Send lookup command
      final lookupCommand = '$atSign\n';
      print('Sending lookup command: ${lookupCommand.trim()}');
      socket.write(lookupCommand);

      // Read response with a timeout
      final response = await _readSocketResponse(socket).timeout(Duration(seconds: 10));

      print('Received response: $response');

      await socket.close();

      // Parse response - format is typically "host:port@" where @ marks the end
      final trimmedResponse = response.trim();

      // Remove trailing @ if present
      final cleanResponse = trimmedResponse.endsWith('@')
          ? trimmedResponse.substring(0, trimmedResponse.length - 1)
          : trimmedResponse;

      if (cleanResponse.isEmpty || cleanResponse.startsWith('null') || cleanResponse.startsWith('error')) {
        throw Exception('AtSign not found in directory');
      }

      // Extract host and port from response
      final parts = cleanResponse.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid response format from atDirectory: $cleanResponse');
      }

      // Remove leading @ from host if present
      final host = parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
      final port = int.tryParse(parts[1]);

      if (port == null) {
        throw Exception('Invalid port number in response: ${parts[1]}');
      }

      return {'host': host, 'port': port};
    } catch (e) {
      print('Exception in _queryAtDirectory: $e');
      socket?.destroy();
      rethrow;
    }
  }

  Future<String> _readSocketResponse(Socket socket) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();

    late StreamSubscription subscription;
    Timer? timeoutTimer;

    timeoutTimer = Timer(Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(TimeoutException('Socket read timeout'));
      }
    });

    subscription = socket.listen(
      (data) {
        final decoded = utf8.decode(data);
        buffer.write(decoded);
        // Check if we have a complete response (ends with newline)
        if (decoded.contains('\n')) {
          timeoutTimer?.cancel();
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        }
      },
      onDone: () {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      onError: (error) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  Future<void> _handle404(HttpRequest request) async {
    request.response.statusCode = 404;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': 'Endpoint not found',
        'path': request.uri.path,
        'availableEndpoints': ['GET /atsign/{atSign}', 'GET /fetch/{atSign}/{keyName}', 'GET /health'],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    await request.response.close();
  }

  Future<void> _handleError(HttpRequest request, dynamic error) async {
    print('Server error: $error');
    request.response.statusCode = 500;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': 'Internal server error',
        'details': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    await request.response.close();
  }

  Future<void> stop() async {
    await _server?.close();
    print('Furl API Server stopped');
  }
}

Future<void> main(List<String> arguments) async {
  int port = 8080;

  // Parse port from command line arguments
  if (arguments.isNotEmpty) {
    final parsedPort = int.tryParse(arguments[0]);
    if (parsedPort != null) {
      port = parsedPort;
    }
  }

  final server = FurlApiServer();

  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nShutting down server...');
    await server.stop();
    exit(0);
  });

  try {
    await server.start(port: port);
  } catch (e) {
    print('Failed to start server: $e');
    exit(1);
  }
}
