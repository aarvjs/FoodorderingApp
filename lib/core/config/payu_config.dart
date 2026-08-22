class PayUConfig {
  /// Merchant Key provided by PayU
  static const String merchantKey = 'oZ9ALM';

  /// Default production/staging backend URL hosting foodadmin Next.js API.
  /// For local development testing only, this can be changed or overridden.
  static const String _defaultBackendUrl = 'https://foodadmin-backend.vercel.app';

  /// Configurable backend API base URL
  static String backendBaseUrl = _defaultBackendUrl;

  /// Environment flag: true for PayU TEST mode, false for PayU PRODUCTION mode
  static bool isTestMode = true;

  /// Endpoint URLs on the foodadmin Next.js backend
  static String get hashApiUrl => '$backendBaseUrl/api/payu/hash';
  static String get verifyApiUrl => '$backendBaseUrl/api/payu/verify';
}
