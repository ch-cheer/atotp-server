import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';
import 'config/app_config.dart';

class ATOTPBackend {
  static final _algorithms = {
    'sha1': sha1,
    'sha256': sha256,
    'sha512': sha512,
  };

  static void init() {
    if (!_algorithms.containsKey(AppConfig.defaultAlgorithm)) {
      throw StateError('Unsupported algorithm: ${AppConfig.defaultAlgorithm}');
    }
    try {
      final _ = AppConfig.address; // ignore: unused_local_variable
    } catch (e) {
      rethrow;
    }
  }

  static String generateSecret({int? length}) {
    final len = length ?? AppConfig.secretLength;
    final random = Random.secure();
    final bytes = List<int>.generate(len, (_) => random.nextInt(256));
    return base32.encode(Uint8List.fromList(bytes)).replaceAll('=', '').toUpperCase();
  }

  static String? normalizeAndValidateSecret(String input) {
    final normalized = AppConfig.normalizeSecret(input);
    return AppConfig.isValidSecret(normalized) ? normalized : null;
  }

  static String generateCode({
    required String generalsecretBase32,
    required String address,
    required String algorithmName,
    required int digits,
    required int period,
  }) {
    final algorithm = _algorithms[algorithmName.toLowerCase()] ?? sha1;
    
    final generalsecret = Uint8List.fromList(base32.decode(generalsecretBase32));
    final addressBytes = Uint8List.fromList(utf8.encode(address));

    final addresssecret = Hmac(algorithm, generalsecret).convert(addressBytes).bytes;

    final counter = DateTime.now().millisecondsSinceEpoch ~/ (period * 1000);
    final counterBytes = Uint8List(8);
    ByteData.view(counterBytes.buffer).setUint64(0, counter, Endian.big);

    final hash = Hmac(algorithm, addresssecret).convert(counterBytes).bytes;

    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
                   ((hash[offset + 1] & 0xff) << 16) |
                   ((hash[offset + 2] & 0xff) << 8) |
                   (hash[offset + 3] & 0xff);

    final code = binary % pow(10, digits).toInt();
    return code.toString().padLeft(digits, '0');
  }

  static int remainingSeconds({int period = 30}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return period - (now % period);
  }
}