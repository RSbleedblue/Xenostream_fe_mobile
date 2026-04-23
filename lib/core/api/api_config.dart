import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Runtime configuration for the XenoStream backend.
///
/// The default [baseUrl] is picked for the current target:
///   - Android emulator          -> http://10.0.2.2:8000   (loopback to host)
///   - iOS simulator / desktop   -> http://127.0.0.1:8000
///   - Web                       -> http://localhost:8000
///
/// Override at runtime by constructing [ApiConfig] with a custom [baseUrl]
/// (e.g. read from a settings screen or `--dart-define=API_BASE_URL=...`).
class ApiConfig {
  const ApiConfig({required this.baseUrl, this.apiKey});

  final String baseUrl;
  final String? apiKey;

  static const String _baseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _apiKeyFromEnv =
      String.fromEnvironment('API_KEY', defaultValue: 'change-me');

  /// Resolves a sensible default backend URL for the current platform.
  factory ApiConfig.defaults() {
    if (_baseUrlFromEnv.isNotEmpty) {
      return ApiConfig(
        baseUrl: _baseUrlFromEnv,
        apiKey: _apiKeyFromEnv.isEmpty ? null : _apiKeyFromEnv,
      );
    }
    return ApiConfig(
      baseUrl: _defaultBaseUrl(),
      apiKey: _apiKeyFromEnv.isEmpty ? null : _apiKeyFromEnv,
    );
  }

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform unavailable (web already handled above).
    }
    return 'http://127.0.0.1:8000';
  }

  ApiConfig copyWith({String? baseUrl, String? apiKey}) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
