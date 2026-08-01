import 'package:flutter/foundation.dart';

/// Where the API lives, per place the app runs.
class AppConfig {
  const AppConfig._();

  /// Override for a real device or a deployed backend:
  /// `flutter run --dart-define=API_BASE_URL=https://api.laostay.la/api`
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator reaches the host machine at 10.0.2.2 — `localhost`
  /// there means the emulator itself, so the request simply fails to connect.
  /// Web and desktop run on the host, where localhost is correct.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3100/api';
    }
    return 'http://localhost:3100/api';
  }

  /// Uploaded photos are served from the same host, outside the `/api` prefix.
  static String get filesBaseUrl {
    final api = apiBaseUrl;
    return api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
  }

  /// Turns `/uploads/2026/08/x.webp` from the API into a URL the app can load.
  static String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$filesBaseUrl$path';
  }

  /// How often an open chat screen asks for new messages.
  static const chatPollInterval = Duration(seconds: 5);
}
