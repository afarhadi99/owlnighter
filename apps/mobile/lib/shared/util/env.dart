/// Compile-time configuration, supplied via `--dart-define`.
///
/// e.g. `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787`
/// (10.0.2.2 is the Android emulator's host loopback).
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

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
