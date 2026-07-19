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

  static const bool _hasSupabaseUrlOverride =
      bool.hasEnvironment('SUPABASE_URL');
  static const String _supabaseUrlOverride =
      String.fromEnvironment('SUPABASE_URL');

  /// Base URL for the local Supabase stack (Kong gateway in front of GoTrue +
  /// Postgres). Same override/resolution order as [apiBaseUrl], but for port
  /// 53321.
  static String get supabaseUrl {
    if (_hasSupabaseUrlOverride && _supabaseUrlOverride.isNotEmpty) {
      return _supabaseUrlOverride;
    }
    if (kIsWeb) return 'http://localhost:53321';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:53321'
        : 'http://localhost:53321';
  }

  /// Supabase anon key. Empty by default — supply the real value via
  /// `--dart-define=SUPABASE_ANON_KEY=...` (see `supabase status` /
  /// `supabase/config.toml`). Real Supabase Auth calls fail with an
  /// "invalid API key" style error until this is set; that is a local config
  /// gap, not something to fabricate here.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
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
