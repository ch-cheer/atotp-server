import 'dart:io';
import 'dart:convert';
import '../config/app_config.dart';
import 'routes.dart';

ServerSocket? _unixServer;

Future<void> startUnixSocket() async {
  if (!AppConfig.enableSocket) return;
  if (!Platform.isLinux) {
    stderr.writeln('! Unix sockets only supported on Linux');
    return;
  }
  
  final path = AppConfig.socketPath;
  if (await File(path).exists()) {
    await File(path).delete();
  }
  
  _unixServer = await ServerSocket.bind(
    InternetAddress(path, type: InternetAddressType.unix), 
    0,
  );
  
  print('Unix socket: $path');
  
  await for (final client in _unixServer!) {
    _handleClient(client);
  }
}

void _handleClient(Socket client) {
  final buffer = StringBuffer();
  
  client.listen(
    (data) {
      buffer.write(utf8.decode(data));
      final content = buffer.toString().trim();
      if (content.isEmpty) return;
      
      try {
        final request = jsonDecode(content);
        final response = handleApiRequest(request);
        client.write(jsonEncode(response));
      } catch (e) {
        client.write(jsonEncode({'error': 'invalid_json', 'message': e.toString()}));
      } finally {
        buffer.clear();
      }
    },
    onDone: () => client.close(),
    onError: (e) {
      stderr.writeln('! Socket error: $e');
      client.close();
    },
  );
}

void stopUnixSocket() {
  _unixServer?.close();
  final path = AppConfig.socketPath;
  if (File(path).existsSync()) {
    File(path).deleteSync();
  }
}