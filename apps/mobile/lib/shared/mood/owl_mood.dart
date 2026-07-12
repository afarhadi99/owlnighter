import '../../services/widget/home_widget_bridge.dart';
import '../theme/theme_re_exports.dart';

/// Maps whether tonight's reading is done (and, if not, the time of day) to
/// the [OwlState] the mascot should show. Reuses the exact day/evening/night
/// bucketing from [readingTimeBucketFor] so the owl's mood always matches the
/// home-screen widget's sense of "how late is it".
OwlState owlMoodFor({required bool hasReadToday, required DateTime now}) {
  if (hasReadToday) return OwlState.cheer;
  return switch (readingTimeBucketFor(now)) {
    ReadingTimeBucket.day => OwlState.idle,
    ReadingTimeBucket.evening => OwlState.worried,
    ReadingTimeBucket.night => OwlState.angry,
  };
}
