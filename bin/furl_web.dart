import 'dart:io';

/// Simple HTTP server to serve the Furl web interface
class FurlWebServer {
  HttpServer? _server;
  final String webRoot;

  FurlWebServer(this.webRoot);

  Future<void> start({int port = 8081}) async {
    _server = await HttpServer.bind('localhost', port);
    print('Furl Web Server started on http://localhost:$port');
    print('Serving files from: $webRoot');
    print('Access the interface at: http://localhost:$port/furl.html');

    await for (HttpRequest request in _server!) {
      await _handleRequest(request);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final uri = request.uri;

      // Add CORS headers
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      // Serve files
      var filePath = uri.path;
      if (filePath == '/') {
        filePath = '/furl.html';
      }

      final file = File('$webRoot$filePath');

      if (await file.exists()) {
        // Determine content type
        String contentType = 'text/plain';
        if (filePath.endsWith('.html')) {
          contentType = 'text/html; charset=utf-8';
        } else if (filePath.endsWith('.js')) {
          contentType = 'application/javascript';
        } else if (filePath.endsWith('.css')) {
          contentType = 'text/css';
        }

        request.response.headers.contentType = ContentType.parse(contentType);
        request.response.statusCode = 200;

        final contents = await file.readAsBytes();
        request.response.add(contents);
        await request.response.close();

        print('Served: ${uri.path} (${contents.length} bytes)');
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
              <p>Available files:</p>
              <ul>
                <li><a href="/furl.html">furl.html</a> - Main Furl interface</li>
              </ul>
            </body>
          </html>
        ''');
        await request.response.close();

        print('404: ${uri.path}');
      }
    } catch (e) {
      print('Error serving request: $e');
      try {
        request.response.statusCode = 500;
        request.response.write('Internal Server Error');
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    await _server?.close();
    print('Furl Web Server stopped');
  }
}

Future<void> main(List<String> arguments) async {
  int port = 8081;
  String webRoot = 'web';

  // Parse command line arguments
  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--port' && i + 1 < arguments.length) {
      final parsedPort = int.tryParse(arguments[i + 1]);
      if (parsedPort != null) port = parsedPort;
    } else if (arguments[i] == '--web-root' && i + 1 < arguments.length) {
      webRoot = arguments[i + 1];
    }
  }

  final server = FurlWebServer(webRoot);

  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nShutting down web server...');
    await server.stop();
    exit(0);
  });

  try {
    await server.start(port: port);
  } catch (e) {
    print('Failed to start web server: $e');
    exit(1);
  }
}
