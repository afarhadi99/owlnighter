import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/theme_re_exports.dart';

/// Thin Dart→native bridge that tells the Android launcher which mood the
/// app's dynamic icon (Duolingo-style) should show.
///
/// This is separate from [HomeWidgetBridge] (see
/// `../widget/home_widget_bridge.dart`), which drives the home-screen
/// AppWidget. The native side (a sibling implementation) owns swapping the
/// actual launcher icon; Dart's only job is to forward the current
/// [OwlState] mood over a platform channel.
///
/// Every call is best-effort and never throws: this is a nice-to-have visual
/// touch, the channel is Android-only, and in tests (or on unsupported
/// platforms) it simply isn't registered. Failures are swallowed (logged in
/// debug) so no call site has to care.
abstract final class AppIconBridge {
  static const MethodChannel _channel = MethodChannel('app.owlnighter/app_icon');

  /// Push the latest mood to the native side so it can update the launcher
  /// icon. [mood]'s `.name` (e.g. `'idle'`, `'worried'`, `'angry'`, `'cheer'`)
  /// is sent as the `'mood'` argument to the `'setMood'` method.
  static Future<void> publish(OwlState mood) async {
    try {
      await _channel.invokeMethod<void>('setMood', {'mood': mood.name});
    } catch (e, s) {
      // Unsupported platform (iOS), missing channel (tests), or no native
      // handler registered yet.
      if (kDebugMode) debugPrint('AppIconBridge.publish skipped: $e\n$s');
    }
  }
}
