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
  final String? sslCertPath;
  final String? sslKeyPath;
  final bool useHttps;

  FurlServer({this.port = 8080, this.webRoot = 'web', this.sslCertPath, this.sslKeyPath})
    : useHttps = sslCertPath != null && sslKeyPath != null;

  Future<void> start() async {
    if (useHttps) {
      // Create SSL context for HTTPS
      final context = SecurityContext();
      context.useCertificateChain(sslCertPath!);
      context.usePrivateKey(sslKeyPath!);

      _server = await HttpServer.bindSecure('localhost', port, context);
      print('🔒 Furl HTTPS Server started on https://localhost:$port');
    } else {
      _server = await HttpServer.bind('localhost', port);
      print('🚀 Furl Server started on http://localhost:$port');
    }

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
        String responseBody = result.stdout.toString().trim();

        // Check if the response indicates the key doesn't exist or has expired
        if (responseBody.contains('error:no such key') ||
            responseBody.contains('Key not found') ||
            responseBody.isEmpty ||
            responseBody.startsWith('error:')) {
          print('⏰ Key not found or expired: $keyName for $normalizedAtSign');
          request.response.statusCode = 404;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'File is no longer available',
              'message': 'The shared file has expired or been removed',
              'atSign': atSign,
              'keyName': keyName,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
          await request.response.close();
          return;
        }

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;

        // Remove "data:" prefix if present
        if (responseBody.startsWith('data:')) {
          responseBody = responseBody.substring(5);
        }

        print('✅ Response body after removing data: prefix: $responseBody');
        request.response.write(responseBody);
      } else {
        // Check if stderr contains "no such key" error
        String errorOutput = result.stderr.toString().toLowerCase();
        if (errorOutput.contains('no such key') ||
            errorOutput.contains('key not found') ||
            errorOutput.contains('not found')) {
          print('⏰ Key not found or expired: $keyName for $normalizedAtSign');
          request.response.statusCode = 404;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'File is no longer available',
              'message': 'The shared file has expired or been removed',
              'atSign': atSign,
              'keyName': keyName,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
          await request.response.close();
          return;
        }

        throw Exception('Curl failed with exit code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Error fetching data for $atSign/$keyName: $e');

      // Check if it's likely a file expiration/not found error
      String errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('no such key') ||
          errorMsg.contains('key not found') ||
          errorMsg.contains('not found') ||
          errorMsg.contains('404')) {
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': 'File is no longer available',
            'message': 'The shared file has expired or been removed',
            'atSign': atSign,
            'keyName': keyName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        // General server error
        request.response.statusCode = 500;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': 'Server error',
            'message': 'Unable to retrieve file data at this time',
            'atSign': atSign,
            'keyName': keyName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      }
    }
    await request.response.close();
  }

  Future<void> _handleFileDownload(HttpRequest request, String fileUrl) async {
    try {
      print('📁 Proxying file download: $fileUrl');

      // According to filebin API, GET /{bin}/{filename} should return 301 redirect to S3
      // But we're getting HTML. Let's try the proper API approach first.

      final httpClient = HttpClient();

      try {
        final uri = Uri.parse(fileUrl);
        final apiRequest = await httpClient.getUrl(uri);

        // Set proper API headers to get 301 redirect instead of HTML page
        apiRequest.headers.set('Accept', 'application/json, application/octet-stream, */*');
        apiRequest.headers.set('User-Agent', 'FurlProxy/1.0 (API Client)');

        // Explicitly disable following redirects so we can handle the 301 ourselves
        apiRequest.followRedirects = false;

        final response = await apiRequest.close();

        print('🔍 Filebin API response: ${response.statusCode}');

        if (response.statusCode == 301 || response.statusCode == 302) {
          // This is the expected behavior! Get the S3 signed URL
          final s3Url = response.headers.value('location');
          if (s3Url != null) {
            print('✅ Got S3 redirect: $s3Url');

            // Now download directly from S3 using efficient streaming
            final s3Request = await httpClient.getUrl(Uri.parse(s3Url));
            final s3Response = await s3Request.close();

            if (s3Response.statusCode == 200) {
              print('📦 Streaming binary data from S3...');
              request.response.statusCode = 200;
              request.response.headers.contentType = ContentType.binary;

              if (s3Response.contentLength >= 0) {
                request.response.headers.contentLength = s3Response.contentLength;
                print('📊 Content-Length: ${s3Response.contentLength} bytes');
              }

              // Efficient streaming without loading into memory
              await s3Response.pipe(request.response);
              print('✅ Successfully streamed file from S3');

              httpClient.close();
              return;
            } else {
              print('❌ S3 download failed: ${s3Response.statusCode}');
            }
          } else {
            print('⚠️ 301 response but no Location header');
          }
        } else if (response.statusCode == 200) {
          // Check if we got binary data directly (fallback case)
          final contentType = response.headers.contentType;
          if (contentType?.mimeType != 'text/html') {
            print('📦 Got binary data directly (no redirect)');
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.binary;

            if (response.contentLength >= 0) {
              request.response.headers.contentLength = response.contentLength;
            }

            await response.pipe(request.response);
            print('✅ Successfully streamed direct binary response');

            httpClient.close();
            return;
          } else {
            print('⚠️ Got HTML instead of expected 301 redirect or binary data');
            // Fall through to curl fallback
          }
        } else if (response.statusCode == 404) {
          throw Exception('File not found (404)');
        } else {
          print('⚠️ Unexpected response code: ${response.statusCode}');
          // Fall through to curl fallback
        }
      } finally {
        httpClient.close();
      }

      // Fallback: Use curl if the API approach didn't work
      print('🔄 Falling back to curl download...');
      final result = await Process.run('curl', ['-s', '-L', fileUrl], stdoutEncoding: null);

      if (result.exitCode == 0) {
        final bytes = result.stdout as List<int>;
        print('📦 Downloaded ${bytes.length} bytes via curl');

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);

        print('✅ Successfully proxied file via curl fallback');
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
  String? sslCertPath;
  String? sslKeyPath;

  // Parse command line arguments
  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--port' && i + 1 < arguments.length) {
      final parsedPort = int.tryParse(arguments[i + 1]);
      if (parsedPort != null) {
        port = parsedPort;
      }
    } else if (arguments[i] == '--web-root' && i + 1 < arguments.length) {
      webRoot = arguments[i + 1];
    } else if (arguments[i] == '--ssl-cert' && i + 1 < arguments.length) {
      sslCertPath = arguments[i + 1];
    } else if (arguments[i] == '--ssl-key' && i + 1 < arguments.length) {
      sslKeyPath = arguments[i + 1];
    } else if (arguments[i] == '--help' || arguments[i] == '-h') {
      print('Furl Unified Server');
      print('');
      print('Usage: dart run bin/furl_server.dart [options]');
      print('');
      print('Options:');
      print('  --port <port>        Server port (default: 8080)');
      print('  --web-root <path>    Web root directory (default: web)');
      print('  --ssl-cert <path>    SSL certificate file for HTTPS');
      print('  --ssl-key <path>     SSL private key file for HTTPS');
      print('  --help, -h           Show this help message');
      print('');
      print('Examples:');
      print('  dart run bin/furl_server.dart');
      print('  dart run bin/furl_server.dart --port 8085');
      print('  dart run bin/furl_server.dart --port 3000 --web-root public');
      print('  dart run bin/furl_server.dart --port 443 --ssl-cert server.crt --ssl-key server.key');
      print('');
      print('HTTPS Notes:');
      print('  - Both --ssl-cert and --ssl-key must be provided for HTTPS');
      print('  - Certificate file should be in PEM format');
      print('  - Private key file should be in PEM format');
      print('  - Default HTTPS port is typically 443 (requires admin privileges)');
      exit(0);
    } else if (!arguments[i].startsWith('--')) {
      // If it's just a number, treat it as port
      final parsedPort = int.tryParse(arguments[i]);
      if (parsedPort != null) {
        port = parsedPort;
      }
    }
  }

  // Validate SSL configuration
  if ((sslCertPath != null) != (sslKeyPath != null)) {
    print('❌ Error: Both --ssl-cert and --ssl-key must be provided for HTTPS');
    print('   Use --help for usage information');
    exit(1);
  }

  if (sslCertPath != null && sslKeyPath != null) {
    // Verify SSL files exist
    if (!File(sslCertPath).existsSync()) {
      print('❌ Error: SSL certificate file not found: $sslCertPath');
      exit(1);
    }
    if (!File(sslKeyPath).existsSync()) {
      print('❌ Error: SSL private key file not found: $sslKeyPath');
      exit(1);
    }
  }

  final server = FurlServer(port: port, webRoot: webRoot, sslCertPath: sslCertPath, sslKeyPath: sslKeyPath);

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
