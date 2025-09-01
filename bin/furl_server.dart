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
  final String bindAddress;
  final int port;
  final String? sslCertPath;
  final String? sslKeyPath;
  final bool useHttps;

  FurlServer({this.port = 8080, this.webRoot = 'web', this.bindAddress = '0.0.0.0', this.sslCertPath, this.sslKeyPath})
    : useHttps = sslCertPath != null && sslKeyPath != null;

  Future<void> start() async {
    if (useHttps) {
      // Create SSL context for HTTPS
      final context = SecurityContext();
      context.useCertificateChain(sslCertPath!);
      context.usePrivateKey(sslKeyPath!);

      _server = await HttpServer.bindSecure(bindAddress, port, context);
      print('🔒 Furl HTTPS Server started on https://$bindAddress:$port');
    } else {
      _server = await HttpServer.bind(bindAddress, port);
      print('🚀 Furl Server started on http://$bindAddress:$port');
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
    print('   Binding to all interfaces: $bindAddress (use --bind 127.0.0.1 for localhost only)');
    print('');

    await for (HttpRequest request in _server!) {
      // Handle each request concurrently (non-blocking)
      _handleRequest(request).catchError((error) {
        print('❌ Unhandled error in request handler: $error');
      });
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString().substring(8); // Last 5 digits
    final startTime = DateTime.now();

    print('🔄 [$requestId] ${request.method} ${request.uri.path} - Started');

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

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('✅ [$requestId] ${request.method} ${request.uri.path} - Completed in ${duration}ms');
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('❌ [$requestId] ${request.method} ${request.uri.path} - Failed in ${duration}ms: $e');
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
      final atSign = uri.queryParameters['atSign'];
      final keyName = uri.queryParameters['keyName'];
      await _handleFileDownload(request, fileUrl, atSign: atSign, keyName: keyName);
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
      final fileSize = await file.length();

      // Set appropriate content type and content length
      final contentType = _getContentType(filePath);
      request.response.headers.contentType = contentType;
      request.response.headers.contentLength = fileSize;

      request.response.statusCode = 200;

      // Stream the file instead of loading into memory
      final fileStream = file.openRead();
      await fileStream.pipe(request.response);

      print('📄 Served: /$filePath ($fileSize bytes)');
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
      case 'wasm':
        return ContentType('application', 'wasm');
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
      late ProcessResult result;
      try {
        result = await Process.run('curl', ['-s', '--url', atServerUrl]);
      } catch (e) {
        if (e is ProcessException && e.errorCode == 2) {
          // curl not found
          throw Exception(
            'curl is required for the furl server but is not installed.\n'
            'Please install curl:\n'
            '  • macOS: curl is pre-installed, try updating your system\n'
            '  • Ubuntu/Debian: sudo apt-get install curl\n'
            '  • CentOS/RHEL: sudo yum install curl\n'
            '  • Windows: Install from https://curl.se/download.html',
          );
        }
        throw Exception('Failed to fetch metadata: $e');
      }

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

  Future<void> _handleFileDownload(HttpRequest request, String fileUrl, {String? atSign, String? keyName}) async {
    try {
      print('📁 Proxying file download with streaming: $fileUrl');

      // Parse and re-encode the URL to handle spaces and special characters properly
      final uri = Uri.parse(fileUrl);
      final encodedUrl = uri.toString();
      print('🔗 Encoded URL: $encodedUrl');

      // First, get the content length with a HEAD request
      print('🔍 Getting file info...');
      late ProcessResult headResult;
      try {
        headResult = await Process.run('curl', [
          '-I', // HEAD request only
          '-s', // Silent
          '-L', // Follow redirects
          '-f', // Fail on HTTP errors
          '--max-time', '30', // 30 second timeout
          '--connect-timeout', '10', // 10 second connect timeout
          '--url', encodedUrl, // Use encoded URL for safer handling
        ]);
      } catch (e) {
        if (e is ProcessException && e.errorCode == 2) {
          // curl not found
          throw Exception(
            'curl is required for the furl server but is not installed.\n'
            'Please install curl:\n'
            '  • macOS: curl is pre-installed, try updating your system\n'
            '  • Ubuntu/Debian: sudo apt-get install curl\n'
            '  • CentOS/RHEL: sudo yum install curl\n'
            '  • Windows: Install from https://curl.se/download.html',
          );
        }
        throw Exception('Failed to get file info: $e');
      }

      int? contentLength;
      if (headResult.exitCode == 0) {
        final headers = headResult.stdout.toString();
        print('📄 HEAD response headers:');
        print(headers);
        final contentLengthMatch = RegExp(r'content-length:\s*(\d+)', caseSensitive: false).firstMatch(headers);
        if (contentLengthMatch != null) {
          contentLength = int.tryParse(contentLengthMatch.group(1)!);
          print('📏 Parsed Content-Length: $contentLength bytes');
        } else {
          print('⚠️ No Content-Length found in HEAD response');
        }
      } else {
        print('❌ HEAD request failed with exit code ${headResult.exitCode}');
        print('❌ HEAD stderr: ${headResult.stderr}');
      }

      // Set response headers for streaming
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.binary;

      // Set content length if we got it from HEAD request
      if (contentLength != null) {
        request.response.headers.contentLength = contentLength;
        print('📊 Set Content-Length header: $contentLength');
      } else {
        // Use chunked encoding if we don't know the length
        request.response.headers.set('Transfer-Encoding', 'chunked');
        print('🔄 Using chunked transfer encoding');
      }

      // Add headers to indicate streaming content
      request.response.headers.set('Cache-Control', 'no-cache');

      // Start curl process for streaming download
      late Process curlProcess;
      try {
        curlProcess = await Process.start('curl', [
          '-s', // Silent (no progress bar)
          '-L', // Follow redirects
          '-f', // Fail on HTTP errors
          '--max-time', '300', // 5 minute timeout
          '--connect-timeout', '30', // 30 second connect timeout
          '--url', encodedUrl, // Use encoded URL for safer handling
        ]);
      } catch (e) {
        if (e is ProcessException && e.errorCode == 2) {
          // curl not found
          throw Exception(
            'curl is required for the furl server but is not installed.\n'
            'Please install curl:\n'
            '  • macOS: curl is pre-installed, try updating your system\n'
            '  • Ubuntu/Debian: sudo apt-get install curl\n'
            '  • CentOS/RHEL: sudo yum install curl\n'
            '  • Windows: Install from https://curl.se/download.html',
          );
        }
        throw Exception('Failed to start file download: $e');
      }

      // Stream the curl stdout directly to the response
      print('🚀 Starting direct stream from curl to client');

      // Create a subscription to monitor the streaming
      int bytesStreamed = 0;
      final stopwatch = Stopwatch()..start();

      final streamSubscription = curlProcess.stdout.listen(
        (List<int> data) {
          bytesStreamed += data.length;
          request.response.add(data);

          // Log progress every MB for large files
          if (contentLength != null && bytesStreamed % (1024 * 1024) == 0) {
            final percent = (bytesStreamed / contentLength * 100).toStringAsFixed(1);
            print('📦 Streamed ${(bytesStreamed / 1024 / 1024).toStringAsFixed(1)}MB (${percent}%)');
          }
        },
        onError: (error) {
          print('❌ Stream error: $error');
        },
        onDone: () {
          stopwatch.stop();
          print('✅ Streaming completed: ${bytesStreamed} bytes in ${stopwatch.elapsedMilliseconds}ms');
        },
      );

      // Monitor stderr for curl errors
      final stderrBuffer = <int>[];
      curlProcess.stderr.listen((List<int> data) {
        stderrBuffer.addAll(data);
      });

      // Wait for curl process to complete
      final exitCode = await curlProcess.exitCode;

      // Cancel the stream subscription
      await streamSubscription.cancel();

      if (exitCode == 0) {
        print('✅ Successfully streamed ${bytesStreamed} bytes directly from source');
      } else {
        final errorMessage = String.fromCharCodes(stderrBuffer);
        print('❌ Curl failed with exit code $exitCode: $errorMessage');

        // If we haven't sent any data yet, we can send an error response
        if (bytesStreamed == 0) {
          request.response.statusCode = 404;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'Could not download file',
              'url': fileUrl,
              'details': 'Curl failed with exit code $exitCode: $errorMessage',
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
        }
      }
    } catch (e) {
      print('❌ Error in streaming download from $fileUrl: $e');

      // Only send error response if we haven't started streaming yet
      try {
        if (request.response.statusCode == 200) {
          // We've already started sending data, can't change status code
          print('⚠️ Cannot send error response - streaming already started');
        } else {
          request.response.statusCode = 500;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': 'Internal server error during streaming',
              'url': fileUrl,
              'details': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
        }
      } catch (responseError) {
        print('❌ Error sending error response: $responseError');
      }
    }

    try {
      await request.response.close();
    } catch (e) {
      print('⚠️ Error closing response: $e');
    }
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
          'GET /api/download?url={url}[&atSign={atSign}&keyName={keyName}]',
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
  String bindAddress = '0.0.0.0'; // Default to all interfaces
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
    } else if ((arguments[i] == '--bind' || arguments[i] == '--host') && i + 1 < arguments.length) {
      bindAddress = arguments[i + 1];
    } else if (arguments[i] == '--ssl-cert' && i + 1 < arguments.length) {
      sslCertPath = arguments[i + 1];
    } else if (arguments[i] == '--ssl-key' && i + 1 < arguments.length) {
      sslKeyPath = arguments[i + 1];
    } else if (arguments[i] == '--help' || arguments[i] == '-h') {
      print('Furl Unified Server');
      print('');
      print('Usage: furl_server [options]');
      print('');
      print('Options:');
      print('  --port <port>        Server port (default: 8080)');
      print('  --bind <address>     Bind address (default: 0.0.0.0 - all interfaces)');
      print('  --host <address>     Alias for --bind');
      print('  --web-root <path>    Web root directory (default: web)');
      print('  --ssl-cert <path>    SSL certificate file for HTTPS');
      print('  --ssl-key <path>     SSL private key file for HTTPS');
      print('  --help, -h           Show this help message');
      print('');
      print('Bind Address Examples:');
      print('  0.0.0.0              Bind to all interfaces (default, accessible externally)');
      print('  127.0.0.1            Bind to localhost only (local access only)');
      print('  192.168.1.100        Bind to specific IP address');
      print('');
      print('Examples:');
      print('  furl_server');
      print('  furl_server --port 8085');
      print('  furl_server --port 3000 --bind 127.0.0.1');
      print('  furl_server --port 3000 --web-root public');
      print('  furl_server --port 443 --ssl-cert server.crt --ssl-key server.key');
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

  final server = FurlServer(
    port: port,
    webRoot: webRoot,
    bindAddress: bindAddress,
    sslCertPath: sslCertPath,
    sslKeyPath: sslKeyPath,
  );

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
