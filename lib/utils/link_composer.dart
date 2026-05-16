import '../config/app_config.dart';

class OtpauthLink {
  static String? build({
    required String label,
    required String secret,
    String? issuer,
    required String algorithm,
    required int digits,
    required int period,
    required int addressOption,
  }) {
    if (!AppConfig.isValidLabel(label)) return null;
    if (issuer != null && !AppConfig.isValidIssuer(issuer)) return null;
    if (!AppConfig.isValidSecret(secret)) return null;
    if (!AppConfig.isValidAlgorithm(algorithm)) return null;
    if (!AppConfig.isValidDigits(digits)) return null;
    if (!AppConfig.isValidPeriod(period)) return null;
    if (!AppConfig.isValidAddressOption(addressOption)) return null;
    
    const defaultAlgorithm = 'sha1';
    const defaultDigits = 6;
    const defaultPeriod = 30;
    const defaultAddressOption = 3;
    
    final params = <String, String>{};
    
    params['secret'] = secret;
    
    if (issuer != null && issuer.isNotEmpty) {
      params['issuer'] = issuer;
    }
    
    if (algorithm.toLowerCase() != defaultAlgorithm) {
      params['algorithm'] = algorithm.toUpperCase();
    }
    
    if (digits != defaultDigits) {
      params['digits'] = digits.toString();
    }
    
    if (period != defaultPeriod) {
      params['period'] = period.toString();
    }
    
    if (addressOption != defaultAddressOption) {
      params['addressOption'] = addressOption.toString();
    }
    
    final query = params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
      
    return 'otpauth://atotp/${Uri.encodeComponent(label)}?$query';
  }
}