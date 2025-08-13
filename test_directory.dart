import 'dart:convert';
import 'dart:io';

/// Simple test client to verify atDirectory lookup
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart test_directory.dart <atsign>');
    print('Available args: $args');
    exit(1);
  }

  final atSign = args[0];
  print('Testing atDirectory lookup for: $atSign');

  Socket? socket;
  try {
    // Connect to atDirectory using TLS
    print('Connecting to root.atsign.org:64...');
    socket = await SecureSocket.connect('root.atsign.org', 64).timeout(Duration(seconds: 10));
    print('Connected!');

    // Send lookup command
    final command = '$atSign\n';
    print('Sending: ${command.replaceAll('\n', '\\n')}');
    socket.write(command);

    // Read response
    final List<int> responseBytes = [];
    await for (final data in socket) {
      responseBytes.addAll(data);
      final response = utf8.decode(responseBytes);
      print('Raw response: ${response.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}');

      // Stop reading after we get a response (should end with newline)
      if (response.contains('\n')) {
        break;
      }
    }

    final finalResponse = utf8.decode(responseBytes).trim();

    // Remove trailing @ if present (atDirectory response format)
    final cleanResponse = finalResponse.endsWith('@')
        ? finalResponse.substring(0, finalResponse.length - 1)
        : finalResponse;

    print('Final response: "$cleanResponse"');

    if (cleanResponse.isEmpty) {
      print('Empty response - atSign might not exist');
    } else if (cleanResponse.contains(':')) {
      final parts = cleanResponse.split(':');
      final host = parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
      print('Host: $host');
      print('Port: ${parts[1]}');
    } else {
      print('Unexpected response format');
    }
    await socket.close();
  } catch (e) {
    print('Error: $e');
    socket?.destroy();
  }
}
