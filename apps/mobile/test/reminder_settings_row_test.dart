import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/settings/settings_page.dart';
import 'package:owlnighter/services/notifications/notification_scheduler.dart';
import 'package:owlnighter/services/notifications/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A scheduler that records calls instead of touching the (absent) platform
/// plugin, so the widget test asserts wiring without a native host.
class _FakeScheduler extends NotificationScheduler {
  _FakeScheduler() : super(FlutterLocalNotificationsPlugin());

  int scheduled = 0;
  int cancelled = 0;
  ReminderTime? lastScheduledTime;

  @override
  Future<void> scheduleDaily(ReminderTime time, {DateTime? now}) async {
    scheduled++;
    lastScheduledTime = time;
  }

  @override
  Future<void> cancel() async => cancelled++;
}

Widget _host(_FakeScheduler scheduler) => ProviderScope(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const MaterialApp(home: SettingsPage()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsPage nightly reminder', () {
    testWidgets('shows the reminder toggle and no "coming soon" placeholder',
        (tester) async {
      await tester.pumpWidget(_host(_FakeScheduler()));
      await tester.pumpAndSettle();

      expect(find.text('Nightly reminder'), findsOneWidget);
      expect(find.text('Coming soon'), findsNothing);
      // Disabled by default → no time row yet.
      expect(find.text('Reminder time'), findsNothing);
    });

    testWidgets('enabling the reminder reveals a time row and schedules it',
        (tester) async {
      final scheduler = _FakeScheduler();
      await tester.pumpWidget(_host(scheduler));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nightly reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder time'), findsOneWidget);
      expect(scheduler.scheduled, greaterThanOrEqualTo(1));
      expect(scheduler.lastScheduledTime, ReminderTime.defaultTime);
    });

    testWidgets('disabling the reminder cancels the schedule', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reminder.enabled': true,
        'reminder.time': '20:00',
      });
      final scheduler = _FakeScheduler();
      await tester.pumpWidget(_host(scheduler));
      await tester.pumpAndSettle();

      // Starts enabled → time row visible.
      expect(find.text('Reminder time'), findsOneWidget);

      await tester.tap(find.text('Nightly reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder time'), findsNothing);
      expect(scheduler.cancelled, greaterThanOrEqualTo(1));
    });
  });
}
