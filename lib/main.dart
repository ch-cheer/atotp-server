import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'backend.dart';
import 'server/socket_handler.dart';
import 'server/routes.dart';
//import 'config/app_config.dart';

Future<void> main(List<String> arguments) async {
  await dotenv.load(fileName: '.env');
  
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('http', defaultsTo: true)
    ..addFlag('socket', defaultsTo: true);
  
  final args = parser.parse(arguments);
  if (args['help']) {
    print('ATOTP Server\n--http : enable HTTP (default: true)\n--socket : enable Unix socket (Linux only)');
    exit(0);
  }

  ATOTPBackend.init();

  if (args['http']) {
    await startHttpServer();
  }
  
  if (args['socket']) {
    await startUnixSocket();
  }

  ProcessSignal.sigint.watch().listen((_) {
    stopUnixSocket();
    exit(0);
  });

  print('ATOTP Server ready');
}