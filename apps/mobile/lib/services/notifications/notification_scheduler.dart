import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A wall-clock time-of-day for the nightly reminder. Kept plugin-free so the
/// scheduling math is unit-testable without a Flutter/timezone host.
class ReminderTime {
  const ReminderTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// The default nudge: 20:00 (8pm) local — a sensible "wind-down" slot.
  static const ReminderTime defaultTime = ReminderTime(20, 0);

  /// Parse the persisted `"HH:mm"` form. Falls back to [defaultTime] on any
  /// malformed input so a corrupt pref can never crash boot.
  factory ReminderTime.parse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return defaultTime;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return defaultTime;
    }
    return ReminderTime(h, m);
  }

  /// Zero-padded `"HH:mm"` for persistence.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime(${format()})';
}

/// Pure time math: the next local [DateTime] at [hour]:[minute] strictly after
/// [now]. If today's slot has already passed (or is exactly now), rolls to
/// tomorrow. Isolated from the plugin so it can be exhaustively unit-tested,
/// including the "target already passed today" case.
DateTime nextDailyFireTime(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

/// Schedules (and cancels) the single daily "nightly reading" local
/// notification via [FlutterLocalNotificationsPlugin.zonedSchedule].
///
/// The tz database is initialized lazily and the local zone is resolved by
/// matching the device's current UTC offset — good enough for a daily wall-clock
/// nudge without pulling in a native timezone-name plugin, and it degrades to
/// UTC rather than throwing if no match is found.
class NotificationScheduler {
  NotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Stable id so re-scheduling replaces (never stacks) the reminder.
  static const int reminderNotificationId = 1001;

  static const String channelId = 'nightly';
  static const String channelName = 'Nightly reminders';
  static const String channelDescription =
      'A gentle nudge to read before bed and keep your streak.';

  /// go_router location tapped-reminders deep-link into (the library home).
  static const String reminderRoute = '/library';

  static bool _tzReady = false;

  /// Idempotently initialize the tz database and pin the local zone.
  static void ensureTimezone() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_resolveDeviceLocation());
    _tzReady = true;
  }

  static tz.Location _resolveDeviceLocation() {
    final offset = DateTime.now().timeZoneOffset;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final loc = tz.getLocation(name);
      if (tz.TZDateTime.now(loc).timeZoneOffset == offset) return loc;
    }
    return tz.UTC;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Schedule the daily reminder at [time]. Any existing reminder is replaced.
  /// [now] is injectable for tests; defaults to the wall clock.
  Future<void> scheduleDaily(ReminderTime time, {DateTime? now}) async {
    ensureTimezone();
    final fireAt = nextDailyFireTime(
      now ?? DateTime.now(),
      time.hour,
      time.minute,
    );
    await _plugin.zonedSchedule(
      reminderNotificationId,
      'Your nightly reading is waiting',
      'Read a few pages tonight and keep your streak alive.',
      tz.TZDateTime.from(fireAt, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Repeat every day at the same wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminderRoute,
    );
  }

  /// Cancel the scheduled reminder (no-op if none is pending).
  Future<void> cancel() => _plugin.cancel(reminderNotificationId);
}
