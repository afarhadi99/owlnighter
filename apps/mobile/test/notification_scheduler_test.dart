import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/services/notifications/notification_scheduler.dart';

void main() {
  group('nextDailyFireTime', () {
    test('returns today when the target time is still ahead', () {
      final now = DateTime(2026, 7, 12, 9, 0);
      final fire = nextDailyFireTime(now, 20, 0);
      expect(fire, DateTime(2026, 7, 12, 20, 0));
    });

    test('rolls to tomorrow when the target time already passed today', () {
      final now = DateTime(2026, 7, 12, 21, 30);
      final fire = nextDailyFireTime(now, 20, 0);
      expect(fire, DateTime(2026, 7, 13, 20, 0));
    });

    test('rolls to tomorrow when the target is exactly now (not "after")', () {
      final now = DateTime(2026, 7, 12, 20, 0);
      final fire = nextDailyFireTime(now, 20, 0);
      expect(fire, DateTime(2026, 7, 13, 20, 0));
    });

    test('fires later the same minute when seconds remain', () {
      final now = DateTime(2026, 7, 12, 19, 59, 30);
      final fire = nextDailyFireTime(now, 20, 0);
      expect(fire, DateTime(2026, 7, 12, 20, 0));
    });

    test('crosses a month/year boundary correctly', () {
      final now = DateTime(2026, 12, 31, 23, 59);
      final fire = nextDailyFireTime(now, 23, 58);
      expect(fire, DateTime(2027, 1, 1, 23, 58));
    });

    test('handles midnight (00:00) target', () {
      final now = DateTime(2026, 7, 12, 0, 1);
      final fire = nextDailyFireTime(now, 0, 0);
      expect(fire, DateTime(2026, 7, 13, 0, 0));
    });
  });

  group('ReminderTime', () {
    test('formats zero-padded HH:mm', () {
      expect(const ReminderTime(8, 5).format(), '08:05');
      expect(const ReminderTime(20, 0).format(), '20:00');
      expect(const ReminderTime(0, 0).format(), '00:00');
    });

    test('parse round-trips a valid stored value', () {
      final t = ReminderTime.parse('07:45');
      expect(t.hour, 7);
      expect(t.minute, 45);
      expect(ReminderTime.parse(t.format()), t);
    });

    test('parse falls back to the default on malformed input', () {
      expect(ReminderTime.parse('nope'), ReminderTime.defaultTime);
      expect(ReminderTime.parse('99:99'), ReminderTime.defaultTime);
      expect(ReminderTime.parse('12'), ReminderTime.defaultTime);
      expect(ReminderTime.parse('12:60'), ReminderTime.defaultTime);
      expect(ReminderTime.parse('24:00'), ReminderTime.defaultTime);
    });

    test('value equality + hashCode', () {
      expect(const ReminderTime(21, 15), const ReminderTime(21, 15));
      expect(
        const ReminderTime(21, 15).hashCode,
        const ReminderTime(21, 15).hashCode,
      );
      expect(const ReminderTime(21, 15) == const ReminderTime(21, 16), false);
    });
  });
}
