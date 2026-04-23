import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend base URL and API key from `--dart-define` or sensible dev defaults.
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.apiKey,
  });

  static const String _baseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _apiKeyFromEnv =
      String.fromEnvironment('API_KEY', defaultValue: 'change-me');

  /// Resolves a sensible default backend URL for the current platform.
  factory ApiConfig.defaults() {
    if (_baseUrlFromEnv.isNotEmpty) {
      return ApiConfig(
        baseUrl: _normalizeBase(_baseUrlFromEnv),
        apiKey: _apiKeyFromEnv,
      );
    }
    if (kIsWeb) {
      return const ApiConfig(baseUrl: 'http://localhost:8000', apiKey: _apiKeyFromEnv);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator → host loopback
      return const ApiConfig(baseUrl: 'http://10.0.2.2:8000', apiKey: _apiKeyFromEnv);
    }
    return const ApiConfig(baseUrl: 'http://localhost:8000', apiKey: _apiKeyFromEnv);
  }

  static String _normalizeBase(String s) {
    if (s.endsWith('/')) return s.substring(0, s.length - 1);
    return s;
  }

  final String baseUrl;
  final String apiKey;
}
