import 'package:design_system/design_system.dart' show OwlState;
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/shared/mood/owl_mood.dart';

void main() {
  group('owlMoodFor', () {
    test('hasReadToday=true → cheer regardless of time (day)', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      expect(
        owlMoodFor(hasReadToday: true, now: now),
        OwlState.cheer,
      );
    });

    test('hasReadToday=true → cheer regardless of time (night)', () {
      final now = DateTime(2026, 1, 1, 22, 0);
      expect(
        owlMoodFor(hasReadToday: true, now: now),
        OwlState.cheer,
      );
    });

    test('hasReadToday=false, day (10:00) → idle', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      expect(
        owlMoodFor(hasReadToday: false, now: now),
        OwlState.idle,
      );
    });

    test('hasReadToday=false, evening (18:00) → worried', () {
      final now = DateTime(2026, 1, 1, 18, 0);
      expect(
        owlMoodFor(hasReadToday: false, now: now),
        OwlState.worried,
      );
    });

    test('hasReadToday=false, night (22:00) → angry', () {
      final now = DateTime(2026, 1, 1, 22, 0);
      expect(
        owlMoodFor(hasReadToday: false, now: now),
        OwlState.angry,
      );
    });
  });
}
