import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sfx/sound_settings.dart' show sharedPreferencesProvider;
import 'notification_scheduler.dart';

/// The persisted nightly-reminder preference: whether it's on, and at what
/// local time. Immutable so Riverpod diffing is cheap.
class ReminderPrefs {
  const ReminderPrefs({required this.enabled, required this.time});

  final bool enabled;
  final ReminderTime time;

  static const ReminderPrefs initial =
      ReminderPrefs(enabled: false, time: ReminderTime.defaultTime);

  ReminderPrefs copyWith({bool? enabled, ReminderTime? time}) => ReminderPrefs(
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderPrefs && other.enabled == enabled && other.time == time;

  @override
  int get hashCode => Object.hash(enabled, time);
}

/// Owns the reminder preference and keeps the scheduled local notification in
/// sync with it. Follows the same write-through [SharedPreferences] pattern as
/// [SoundSettingsController]: state is held in memory for cheap reads and
/// persisted best-effort on every change.
class ReminderController extends StateNotifier<ReminderPrefs> {
  ReminderController(this._prefsFuture, this._scheduler)
      : super(ReminderPrefs.initial) {
    _load();
  }

  static const _enabledKey = 'reminder.enabled';
  static const _timeKey = 'reminder.time';

  final Future<SharedPreferences> _prefsFuture;
  final NotificationScheduler _scheduler;

  Future<void> _load() async {
    try {
      final prefs = await _prefsFuture;
      final enabled = prefs.getBool(_enabledKey) ?? false;
      final rawTime = prefs.getString(_timeKey);
      state = ReminderPrefs(
        enabled: enabled,
        time: rawTime == null
            ? ReminderTime.defaultTime
            : ReminderTime.parse(rawTime),
      );
      // Re-arm the OS schedule on launch so it survives reboots/reinstalls.
      await _apply();
    } catch (_) {
      // Preferences/plugin unavailable (e.g. a plain test host): keep the
      // in-memory default rather than throwing during boot.
    }
  }

  /// Turn the nightly reminder on or off, persisting and (un)scheduling.
  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _persist();
    await _apply();
  }

  /// Change the reminder time; reschedules if the reminder is enabled.
  Future<void> setTime(ReminderTime time) async {
    state = state.copyWith(time: time);
    await _persist();
    await _apply();
  }

  Future<void> _persist() async {
    try {
      final prefs = await _prefsFuture;
      await prefs.setBool(_enabledKey, state.enabled);
      await prefs.setString(_timeKey, state.time.format());
    } catch (_) {
      // Persist failures are non-fatal; in-memory state still drives the UI.
    }
  }

  Future<void> _apply() async {
    try {
      if (state.enabled) {
        await _scheduler.scheduleDaily(state.time);
      } else {
        await _scheduler.cancel();
      }
    } catch (_) {
      // Scheduling failures (no plugin in a test host, permission denied) must
      // not crash the settings flow — the persisted preference is the source of
      // truth and we re-arm on next launch.
    }
  }
}

/// The one shared local-notifications plugin instance, used by both push
/// (foreground display) and the reminder scheduler. Initialized in bootstrap.
final localNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

/// The daily-reminder scheduler over the shared plugin.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(ref.watch(localNotificationsProvider));
});

/// The nightly-reminder preference + scheduling controller. Toggle/set via
/// `.notifier`.
final reminderControllerProvider =
    StateNotifierProvider<ReminderController, ReminderPrefs>((ref) {
  return ReminderController(
    ref.watch(sharedPreferencesProvider),
    ref.watch(notificationSchedulerProvider),
  );
});
