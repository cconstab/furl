import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Unified Furl server that combines API and web serving functionality
/// Handles both atSign resolution/data fetching and static file serving
class FurlServer {
  static const String atDirectoryHost = 'root.atsign.org';
  static const int atDirectoryPort = 64;

  HttpServer? _server;
  final String webRoot;
  final int port;

  FurlServer({this.port = 8080, this.webRoot = 'web'});

  Future<void> start() async {
    _server = await HttpServer.bind('localhost', port);
    print('🚀 Furl Server started on http://localhost:$port');
    print('📊 API Endpoints:');
    print('   GET /api/atsign/{atSign} - Get FQDN:PORT for an atSign');
    print('   GET /api/fetch/{atSign}/{keyName} - Fetch public atKey data');
    print('   GET /api/download?url={url} - Proxy file downloads');
    print('   GET /api/health - Health check');
    print('🌐 Web Interface:');
    print('   GET / - Redirect to furl.html');
    print('   GET /furl.html - File decryption interface');
    print('   Static files served from: $webRoot/');
    print('');

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

      // API endpoints (prefixed with /api/)
      if (uri.path.startsWith('/api/')) {
        await _handleApiRequest(request, uri);
      } else {
        // Static file serving
        await _handleStaticFile(request, uri);
      }
    } catch (e) {
      await _handleError(request, e);
    }
  }

  Future<void> _handleApiRequest(HttpRequest request, Uri uri) async {
    final apiPath = uri.path.substring(4); // Remove '/api' prefix
    final pathSegments = uri.pathSegments.skip(1).toList(); // Skip 'api' segment

    if (apiPath == '/health') {
      await _handleHealth(request);
    } else if (apiPath == '/download' && uri.queryParameters.containsKey('url')) {
      final fileUrl = uri.queryParameters['url']!;
      await _handleFileDownload(request, fileUrl);
    } else if (pathSegments.length == 2 && pathSegments[0] == 'atsign') {
      final atSign = pathSegments[1];
      await _handleAtSignLookup(request, atSign);
    } else if (pathSegments.length == 3 && pathSegments[0] == 'fetch') {
      final atSign = pathSegments[1];
      final keyName = pathSegments[2];
      await _handleFetchData(request, atSign, keyName);
    } else {
      await _handleApiNotFound(request);
    }
  }

  Future<void> _handleStaticFile(HttpRequest request, Uri uri) async {
    var filePath = uri.path;

    // Handle root path
    if (filePath == '/') {
      filePath = '/furl.html';
    }

    // Remove leading slash
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    final file = File('$webRoot/$filePath');

    if (await file.exists()) {
      final fileBytes = await file.readAsBytes();

      // Set appropriate content type
      final contentType = _getContentType(filePath);
      request.response.headers.contentType = contentType;

      request.response.statusCode = 200;
      request.response.add(fileBytes);

      print('📄 Served: /$filePath (${fileBytes.length} bytes)');
    } else {
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
        <!DOCTYPE html>
        <html>
        <head><title>404 Not Found</title></head>
        <body>
          <h1>404 Not Found</h1>
          <p>The requested file was not found.</p>
          <p><a href="/furl.html">Go to Furl Interface</a></p>
        </body>
        </html>
      ''');

      print('❌ 404: /$filePath not found');
    }

    await request.response.close();
  }

  ContentType _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'html':
        return ContentType.html;
      case 'css':
        return ContentType('text', 'css');
      case 'js':
        return ContentType('application', 'javascript');
      case 'json':
        return ContentType.json;
      case 'png':
        return ContentType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'gif':
        return ContentType('image', 'gif');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'ico':
        return ContentType('image', 'x-icon');
      default:
        return ContentType.binary;
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'furl-unified-server',
        'version': '1.0.0',
        'endpoints': {
          'api': ['health', 'atsign', 'fetch', 'download'],
          'web': ['/', 'furl.html', 'static files'],
        },
      }),
    );
    await request.response.close();
  }

  Future<void> _handleAtSignLookup(HttpRequest request, String atSign) async {
    try {
      // Ensure atSign starts with @
      final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';
      // But send to atDirectory without the @
      final lookupAtSign = normalizedAtSign.substring(1);

      print('🔍 Looking up atServer details for: $normalizedAtSign (sending: $lookupAtSign)');

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
      print('❌ Error looking up $atSign: $e');
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

      print('📥 Fetching data for: $normalizedAtSign, key: $keyName');

      // First get the atServer details
      final lookupAtSign = normalizedAtSign.substring(1);
      final atServerInfo = await _queryAtDirectory(lookupAtSign);
      final host = atServerInfo['host'];
      final port = atServerInfo['port'];

      // Fetch the data from the atServer using curl (since it works reliably)
      final atServerUrl = 'https://$host:$port/public:$keyName.furl$normalizedAtSign';
      print('🌐 Fetching from atServer: $atServerUrl');

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

        print('✅ Response body after removing data: prefix: $responseBody');
        request.response.write(responseBody);
      } else {
        throw Exception('Curl failed with exit code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Error fetching data for $atSign/$keyName: $e');
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
      print('📁 Proxying file download: $fileUrl');

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
      print('❌ Error downloading file from $fileUrl: $e');
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
      print('🔌 Connecting to atDirectory at $atDirectoryHost:$atDirectoryPort');

      // Connect to atDirectory using TLS
      socket = await SecureSocket.connect(atDirectoryHost, atDirectoryPort).timeout(Duration(seconds: 10));

      // Send lookup command
      final lookupCommand = '$atSign\n';
      print('📤 Sending lookup command: ${lookupCommand.trim()}');
      socket.write(lookupCommand);

      // Read response with a timeout
      final response = await _readSocketResponse(socket).timeout(Duration(seconds: 10));

      print('📥 Received response: $response');

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
      print('❌ Exception in _queryAtDirectory: $e');
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

  Future<void> _handleApiNotFound(HttpRequest request) async {
    request.response.statusCode = 404;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': 'API endpoint not found',
        'path': request.uri.path,
        'availableEndpoints': [
          'GET /api/atsign/{atSign}',
          'GET /api/fetch/{atSign}/{keyName}',
          'GET /api/download?url={url}',
          'GET /api/health',
        ],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    await request.response.close();
  }

  Future<void> _handleError(HttpRequest request, dynamic error) async {
    print('💥 Server error: $error');
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
    print('🛑 Furl Server stopped');
  }
}

Future<void> main(List<String> arguments) async {
  int port = 8080;
  String webRoot = 'web';

  // Parse command line arguments
  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--port' && i + 1 < arguments.length) {
      final parsedPort = int.tryParse(arguments[i + 1]);
      if (parsedPort != null) {
        port = parsedPort;
      }
    } else if (arguments[i] == '--web-root' && i + 1 < arguments.length) {
      webRoot = arguments[i + 1];
    } else if (arguments[i] == '--help' || arguments[i] == '-h') {
      print('Furl Unified Server');
      print('');
      print('Usage: dart run bin/furl_server.dart [options]');
      print('');
      print('Options:');
      print('  --port <port>        Server port (default: 8080)');
      print('  --web-root <path>    Web root directory (default: web)');
      print('  --help, -h           Show this help message');
      print('');
      print('Examples:');
      print('  dart run bin/furl_server.dart');
      print('  dart run bin/furl_server.dart --port 8085');
      print('  dart run bin/furl_server.dart --port 3000 --web-root public');
      exit(0);
    } else if (!arguments[i].startsWith('--')) {
      // If it's just a number, treat it as port
      final parsedPort = int.tryParse(arguments[i]);
      if (parsedPort != null) {
        port = parsedPort;
      }
    }
  }

  final server = FurlServer(port: port, webRoot: webRoot);

  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\n🛑 Shutting down server...');
    await server.stop();
    exit(0);
  });

  try {
    await server.start();
  } catch (e) {
    print('❌ Failed to start server: $e');
    exit(1);
  }
}
