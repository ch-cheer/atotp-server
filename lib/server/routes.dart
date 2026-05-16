import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../config/app_config.dart';
import '../backend.dart';
import '../utils/link_composer.dart';

final _faviconBytes = Uint8List.fromList(
  base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAEUlEQVR42mP8z8DwHwYGAQoABgBpLQAAAABJRU5ErkJggg=='),
);

Future<void> startHttpServer() async {
  final router = Router()
    ..get('/favicon.ico', _handleFavicon)
    ..post('/register', _handleRegister)
    ..post('/verify', _handleVerify)
    ..get('/health', (req) => Response.ok('OK'));
  
  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((request) => router.call(request));
  
  try {
    await io.serve(pipeline, InternetAddress.anyIPv4, AppConfig.httpPort);
    print('HTTP: port ${AppConfig.httpPort}');
  } on SocketException catch (e) {
    if (e.osError?.errorCode == 10048 ||  // Windows: WSAEADDRINUSE
        e.message.contains('already in use') ||  // Linux/macOS
        e.message.contains('address already in use')) {
      stderr.writeln('Error: Port ${AppConfig.httpPort} is already in use.');
      stderr.writeln('Solutions:');
      stderr.writeln('- Stop the process using port ${AppConfig.httpPort}');
      stderr.writeln('- Change HTTP_PORT in .env to a free port');
      stderr.writeln('- Use --help to see available options');
      exit(1);
    } else {
      stderr.writeln('Failed to start HTTP server: ${e.message}');
      exit(1);
    } 
  }catch (e) {
    stderr.writeln('Unexpected error starting HTTP server: $e');
    exit(1);
  }
}

Map<String, dynamic> handleApiRequest(Map<String, dynamic> req) {
  final action = req['action'] as String?;
  switch (action) {
    case 'register':
      return _processRegister(req['username'] as String?);
    case 'verify':
      return _processVerify(
        username: req['username'] as String?,
        secret: req['secret'] as String?,
        clientCode: req['code'] as String?,
      );
    default:
      return {'error': 'unknown_action', 'supported': ['register', 'verify']};
  }
}

Future<Response> _handleRegister(Request req) async {
  try {
    final body = await req.readAsString();
    final data = jsonDecode(body);
    final result = _processRegister(data['username']);
    return Response.ok(jsonEncode(result), headers: {'content-type': 'application/json'});
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_request'}));
  }
}

Map<String, dynamic> _processRegister(String? username) {
  if (username == null || !AppConfig.isValidLabel(username)) {
    return {'error': 'invalid_username', 'rule': '1–50 characters, not empty'};
  }
  
  final secret = ATOTPBackend.generateSecret();
  final otpauthUrl = OtpauthLink.build(
    label: username,
    secret: secret,
    issuer: AppConfig.defaultIssuer.isEmpty ? null : AppConfig.defaultIssuer,
    algorithm: AppConfig.defaultAlgorithm,
    digits: AppConfig.defaultDigits,
    period: AppConfig.defaultPeriod,
    addressOption: AppConfig.defaultAddressOption,
  );
  
  if (otpauthUrl == null) {
    return {'error': 'config_error', 'message': 'Invalid default config for otpauth link'};
  }
  
  return {
    'username': username,
    'secret': secret,
    'otpauth_url': otpauthUrl,
    'note': 'Server does not store secret. Client must save it securely.',
  };
}

Future<Response> _handleVerify(Request req) async {
  try {
    final body = await req.readAsString();
    final data = jsonDecode(body);
    final result = _processVerify(
      username: data['username'],
      secret: data['secret'],
      clientCode: data['code'],
    );
    return Response.ok(jsonEncode(result), headers: {'content-type': 'application/json'});
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_request'}));
  }
}

Response _handleFavicon(Request req) {
  return Response.ok(
    _faviconBytes,
    headers: {
      'content-type': 'image/png',
      'cache-control': 'public, max-age=86400',
    },
  );
}

Map<String, dynamic> _processVerify({
  String? username,
  String? secret,
  String? clientCode,
}) {
  // Валидация входных данных
  if (username == null || !AppConfig.isValidLabel(username)) {
    return {'error': 'invalid_username'};
  }
  if (secret == null || !AppConfig.isValidSecret(secret)) {
    return {'error': 'invalid_secret', 'rule': 'base32, 16+ chars, A-Z2-7'};
  }
  if (!AppConfig.isValidClientCode(clientCode)) {
    return {'error': 'invalid_code', 'rule': 'numeric, max 12 digits'};
  }
  
  final normalizedSecret = ATOTPBackend.normalizeAndValidateSecret(secret)!;
  final address = AppConfig.address;
  
  final serverCode = ATOTPBackend.generateCode(
    generalsecretBase32: normalizedSecret,
    address: address,
    algorithmName: AppConfig.defaultAlgorithm,
    digits: AppConfig.defaultDigits,
    period: AppConfig.defaultPeriod,
  );
  
  final remaining = ATOTPBackend.remainingSeconds(period: AppConfig.defaultPeriod);
  final valid = serverCode == clientCode;
  
  return {
    'username': username,
    'valid': valid,
    'remaining_seconds': remaining,
    'server_code': serverCode, //отладка
  };
}