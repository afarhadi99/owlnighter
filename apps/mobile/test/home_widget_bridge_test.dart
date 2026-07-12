import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/services/widget/home_widget_bridge.dart';

/// Unit tests for the Dart mirror of the widget's time-of-day bucketing. The
/// native Kotlin `ReadingWidgetProvider.timeBucket` uses the identical
/// boundaries; these lock the Dart side so the two never drift.
void main() {
  group('readingTimeBucketFor', () {
    ReadingTimeBucket at(int hour) =>
        readingTimeBucketFor(DateTime(2026, 7, 11, hour, 30));

    test('early morning is night (streak-at-risk window)', () {
      expect(at(0), ReadingTimeBucket.night);
      expect(at(4), ReadingTimeBucket.night);
    });

    test('5:00 flips to day', () {
      expect(at(5), ReadingTimeBucket.day);
      expect(at(9), ReadingTimeBucket.day);
      expect(at(16), ReadingTimeBucket.day);
    });

    test('17:00 flips to evening', () {
      expect(at(17), ReadingTimeBucket.evening);
      expect(at(19), ReadingTimeBucket.evening);
      expect(at(20), ReadingTimeBucket.evening);
    });

    test('21:00 flips to night', () {
      expect(at(21), ReadingTimeBucket.night);
      expect(at(23), ReadingTimeBucket.night);
    });

    test('boundary hours land in exactly one bucket', () {
      // Every hour of the day maps to a single, defined bucket.
      for (var h = 0; h < 24; h++) {
        expect(() => at(h), returnsNormally);
      }
    });
  });
}
