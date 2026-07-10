import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Compile-time + runtime configuration.
///
/// A `--dart-define` always wins (e.g.
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8787`). When none
/// is supplied we resolve a host that can reach a dev API running on the host
/// machine.
abstract final class AppEnv {
  // Whether an explicit override was passed at build time. `hasEnvironment` is
  // const and lets us tell "unset" apart from "set to the default value".
  static const bool _hasApiBaseUrlOverride =
      bool.hasEnvironment('API_BASE_URL');
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');

  /// Base URL for the owlnighter API.
  ///
  /// Resolution order:
  /// 1. an explicit `--dart-define=API_BASE_URL` (any platform);
  /// 2. Android → `http://10.0.2.2:8787` (the emulator's alias for the host
  ///    loopback — `localhost` inside the emulator is the emulator itself);
  /// 3. everything else (iOS simulator, desktop, web) → `http://localhost:8787`.
  static String get apiBaseUrl {
    if (_hasApiBaseUrlOverride && _apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    // Guard web first: dart:io's Platform is unavailable there, and web can
    // always reach the host directly on localhost.
    if (kIsWeb) return 'http://localhost:8787';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8787'
        : 'http://localhost:8787';
  }

  /// Universal-link host, used to recognise inbound https deep links.
  static const String appLinkHost = String.fromEnvironment(
    'APP_LINK_HOST',
    defaultValue: 'app.example.com',
  );

  static const bool enableAdminDebug = bool.fromEnvironment(
    'ENABLE_ADMIN_DEBUG',
    defaultValue: true,
  );
}
