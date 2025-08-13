import 'dart:io';
import 'dart:convert';

/// Simple test to debug atServer HTTP communication
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart debug_atserver.dart <host> <port> [path]');
    exit(1);
  }

  final host = args[0];
  final port = int.parse(args[1]);
  final path = args.length > 2 ? args[2] : '/public:publickey';

  Socket? socket;
  try {
    print('Connecting to $host:$port...');
    socket = await SecureSocket.connect(host, port, onBadCertificate: (cert) => true);
    print('Connected!');

    // Send HTTP GET request
    final request = 'GET $path HTTP/1.1\r\nHost: $host:$port\r\nConnection: close\r\n\r\n';
    print('Sending HTTP request:');
    print(request.replaceAll('\r\n', '\\r\\n'));

    socket.write(request);

    // Read response
    final List<int> responseBytes = [];
    await for (final data in socket) {
      responseBytes.addAll(data);
    }

    final response = utf8.decode(responseBytes);
    print('\nRaw response:');
    print(response);

    // Try to parse HTTP response
    final lines = response.split('\r\n');
    if (lines.isNotEmpty) {
      print('\nStatus line: ${lines[0]}');

      // Find the body (after empty line)
      int bodyStart = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].isEmpty) {
          bodyStart = i + 1;
          break;
        }
      }

      if (bodyStart > 0 && bodyStart < lines.length) {
        final body = lines.sublist(bodyStart).join('\r\n');
        print('Body: $body');
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    socket?.destroy();
  }
}
