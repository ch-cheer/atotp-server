import 'dart:io';

class AppConfig {
  static late final Map<String, String> _config;
  static bool _initialized = false;

  static void initialize(Map<String, String> configMap) {
    if (_initialized) return;
    _config = configMap;
    _initialized = true;
  }

  // === Вспомогательный метод валидации ===
  static T _validate<T>(String key, T? value, bool Function(T) validator, String message) {
    if (value == null || !validator(value)) {
      stderr.writeln('Invalid config: $key — $message');
      exit(1);
    }
    return value;
  }
  
  static int get httpPort {
    final raw = _config['HTTP_PORT'] ?? '8080';
    final port = int.tryParse(raw);
    return _validate(
      'HTTP_PORT',
      port,
      (p) => p != null && p > 0 && p < 65536,
      'must be a number between 1 and 65535',
    )!;
  }

  static String get socketPath {
    final path = _config['SOCKET_PATH'] ?? '/tmp/atotp.sock';
    return _validate(
      'SOCKET_PATH',
      path,
      (p) => p.isNotEmpty && p.startsWith('/'),
      'must be an absolute path starting with /',
    );
  }

  static bool get enableSocket {
    final raw = (_config['ENABLE_SOCKET'] ?? 'true').toLowerCase();
    return _validate(
      'ENABLE_SOCKET',
      raw,
      (v) => v == 'true' || v == 'false' || v == '1' || v == '0',
      'must be a boolean: true/false/1/0',
    ) == 'true' || raw == '1';
  }

  static String get defaultIssuer => _config['DEFAULT_ISSUER'] ?? 'MyApp';

  static String get defaultAlgorithm {
    final algo = _config['DEFAULT_ALGORITHM'] ?? 'sha1';
    return _validate(
      'DEFAULT_ALGORITHM',
      algo,
      isValidAlgorithm,
      'must be one of: sha1, sha256, sha512',
    );
  }

  static int get defaultDigits {
    final raw = _config['DEFAULT_DIGITS'] ?? '6';
    final digits = int.tryParse(raw);
    return _validate(
      'DEFAULT_DIGITS',
      digits,
      (d) => d != null && isValidDigits(d),
      'must be a number between 6 and 12',
    )!;
  }

  static int get defaultPeriod {
    final raw = _config['DEFAULT_PERIOD'] ?? '30';
    final period = int.tryParse(raw);
    return _validate(
      'DEFAULT_PERIOD',
      period,
      (p) => p != null && isValidPeriod(p),
      'must be one of: 15, 30, 60',
    )!;
  }

  static int get defaultAddressOption {
    final raw = _config['DEFAULT_ADDRESS_OPTION'] ?? '3';
    final opt = int.tryParse(raw);
    return _validate(
      'DEFAULT_ADDRESS_OPTION',
      opt,
      (o) => o != null && isValidAddressOption(o),
      'must be a number between 1 and 3',
    )!;
  }

  static String get address {
    final addr = _config['ADDRESS'];
    final option = defaultAddressOption;
    return _validate(
      'ADDRESS',
      addr,
      (a) => isValidAddress(a, option),
      'must be valid for addressOption=$option (1=IP, 2=URL, 3=IP,URL)',
    ).trim();
  }

  static int get secretLength {
    final raw = _config['SECRET_LENGTH'] ?? '20';
    final len = int.tryParse(raw);
    return _validate(
      'SECRET_LENGTH',
      len,
      (l) => l != null && l >= 16 && l <= 32,
      'must be a number between 16 and 32',
    )!;
  }
  
  static bool isValidLabel(String label) {
    final validLabel = label.trim();
    return validLabel.isNotEmpty && validLabel.length <= 50;
  }

  static bool isValidIssuer(String issuer) => issuer.trim().length <= 50;

  static String normalizeSecret(String secret) => secret.trim().replaceAll(' ', '').toUpperCase();

  static bool isValidSecret(String secret) {
    final validSecret = normalizeSecret(secret);
    final regex = RegExp(r'^[A-Z2-7]+$');
    return validSecret.isNotEmpty && validSecret.length >= 16 && regex.hasMatch(validSecret);
  }

  static bool isValidAlgorithm(String algorithm) {
    final validAlgorithm = algorithm.trim().toLowerCase();
    return validAlgorithm == 'sha1' || validAlgorithm == 'sha256' || validAlgorithm == 'sha512';
  }

  static bool isValidDigits(int digits) => digits >= 6 && digits <= 12;

  static bool isValidPeriod(int period) => period == 15 || period == 30 || period == 60;

  static bool isValidAddressOption(int addressOption) => addressOption >= 1 && addressOption <= 3;

  static bool isValidClientCode(String? code) {
    if (code == null || code.isEmpty) return false;
    final cleaned = code.trim();
    return cleaned.length <= 12 && RegExp(r'^\d+$').hasMatch(cleaned);
  }

  static bool isValidIpAddress(String ip) {
    final validIp = ip.trim();
    if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(validIp)) return false;
    final parts = validIp.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  static bool isValidUrl(String url) {
    final validUrl = url.trim();
    if (!validUrl.startsWith('http://') && !validUrl.startsWith('https://')) return false;
    try {
      final uri = Uri.parse(validUrl);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  static bool isValidAddress(String address, int addressOption) {
    final validAddress = address.trim();
    if (validAddress.isEmpty) return false;
    
    switch (addressOption) {
      case 1: return isValidIpAddress(validAddress);
      case 2: return isValidUrl(validAddress);
      case 3:
        final parts = validAddress.split(',').map((s) => s.trim()).toList();
        if (parts.length != 2) return false;
        return isValidIpAddress(parts[0]) && isValidUrl(parts[1]);
      default: return false;
    }
  }
}