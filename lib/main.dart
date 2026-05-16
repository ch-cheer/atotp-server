import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'backend.dart';
import 'server/socket_handler.dart';
import 'server/routes.dart';
import 'config/app_config.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('http', defaultsTo: true)
    ..addFlag('socket', defaultsTo: true)
    ..addOption('config', abbr: 'c', defaultsTo: 'config.txt', help: 'Path to config file');
  
  final args = parser.parse(arguments);
  if (args['help']) {
    print('ATOTP Server\n--http : enable HTTP\n--socket : enable Unix socket (Linux only)\n-c, --config : path to configuration file');
    exit(0);
  }

  final configFile = File(args['config']);

  if (!configFile.existsSync()) {
    print('Configuration file not found. Creating default "${configFile.path}"...');
    configFile.writeAsStringSync('''# ATOTP Server Configuration
# Generated automatically on first run

# === Server ===
HTTP_PORT=8080
SOCKET_PATH=/tmp/atotp.sock
ENABLE_SOCKET=true

# === ATOTP defaults ===
DEFAULT_ISSUER=MyApp
DEFAULT_ALGORITHM=sha1
DEFAULT_DIGITS=6
DEFAULT_PERIOD=30
DEFAULT_ADDRESS_OPTION=3

# === ADDRESS (обязательно, формат зависит от addressOption) ===
# addressOption=1: только IP (192.168.1.1)
# addressOption=2: только URL (https://example.com)
# addressOption=3: IP и URL через запятую (192.168.1.1,https://example.com)
ADDRESS=127.0.0.1,https://example.com

# === Security ===
SECRET_LENGTH=20
''');
    print('Please edit "${configFile.path}" if needed, then restart the server.\n');
  }

  // Парсинг конфига
  final Map<String, String> configMap = {};
  try {
    final lines = configFile.readAsLinesSync(encoding: utf8);
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex == -1) continue;

      final key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      configMap[key] = value;
    }
    
    AppConfig.initialize(configMap);
  } catch (e) {
    stderr.writeln('Error reading configuration file: $e');
    exit(1);
  }

  ATOTPBackend.init();

  // Запуск серверов
  if (args['http']) startHttpServer();
  if (args['socket']) startUnixSocket();

  // Graceful shutdown
  ProcessSignal.sigint.watch().listen((_) {
    stopUnixSocket();
    exit(0);
  });

  print('ATOTP Server ready');
}