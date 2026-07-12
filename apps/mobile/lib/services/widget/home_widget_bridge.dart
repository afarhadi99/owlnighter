import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Which part of the day it is, for the home-screen widget's visual state.
///
/// This mirrors the identical bucketing done natively in Kotlin
/// (`ReadingWidgetProvider.timeBucket`). We keep a Dart copy so the boundaries
/// live in one testable place and stay in sync with the native widget — the
/// native side is the runtime source of truth (it recomputes the bucket from
/// the device clock on every `onUpdate`, even when the app is closed).
enum ReadingTimeBucket { day, evening, night }

/// Maps a wall-clock [now] to a [ReadingTimeBucket].
///
/// Boundaries (must match `ReadingWidgetProvider.timeBucket` in Kotlin):
///   * night   — 21:00 up to (but not including) 05:00  (streak at risk)
///   * evening — 17:00 up to 21:00
///   * day     — 05:00 up to 17:00
ReadingTimeBucket readingTimeBucketFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 21 || hour < 5) return ReadingTimeBucket.night;
  if (hour >= 17) return ReadingTimeBucket.evening;
  return ReadingTimeBucket.day;
}

/// Thin Dart→native bridge that pushes the two pieces of state the Android
/// home-screen widget renders from into the shared preferences the
/// `home_widget` plugin owns, then asks Android to redraw the widget.
///
/// The native [ReadingWidgetProvider] reads `hasReadToday` and `currentStreak`
/// back out of those same preferences and computes the time-of-day bucket
/// itself, so the only thing Dart has to keep fresh is *whether tonight's
/// reading is done* and *the current streak number*.
///
/// Every call is best-effort and never throws: the widget is a nice-to-have,
/// the plugin is Android/iOS-only, and in tests the platform channel isn't
/// registered. Failures are swallowed (logged in debug) so no call site has to
/// care.
abstract final class HomeWidgetBridge {
  /// Must match the Kotlin class name registered as the widget receiver.
  static const String _androidProvider = 'ReadingWidgetProvider';

  static const String keyHasReadToday = 'hasReadToday';
  static const String keyCurrentStreak = 'currentStreak';

  /// Persist the latest reading state and redraw the widget.
  static Future<void> publish({
    required bool hasReadToday,
    required int currentStreak,
  }) async {
    try {
      await HomeWidget.saveWidgetData<bool>(keyHasReadToday, hasReadToday);
      await HomeWidget.saveWidgetData<int>(keyCurrentStreak, currentStreak);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e, s) {
      // Unsupported platform, missing plugin (tests), or no widget placed yet.
      if (kDebugMode) debugPrint('HomeWidgetBridge.publish skipped: $e\n$s');
    }
  }
}
