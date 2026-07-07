import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline/offline.dart';

import '../offline_sync/offline_providers.dart';

/// Minimal analytics facade. Events are written to the local
/// `local_session_events` table and flushed later by the sync layer, so we
/// never lose behavioral signal when offline. Swap the sink for a real
/// analytics SDK behind this same interface if needed.
class Analytics {
  Analytics(this._cache);
  final OfflineCache _cache;

  Future<void> log(String event, {Map<String, dynamic> props = const {}}) =>
      _cache.logEvent(event, props);

  // Named helpers for the core loop, so call sites stay consistent.
  Future<void> sessionStarted(String stepId) =>
      log('session_started', props: {'stepId': stepId});
  Future<void> quizSubmitted(String quizId, {required bool passed}) =>
      log('quiz_submitted', props: {'quizId': quizId, 'passed': passed});
  Future<void> streakCelebrated(int streak) =>
      log('streak_celebrated', props: {'streak': streak});
}

final analyticsProvider = Provider<Analytics>((ref) {
  return Analytics(ref.watch(offlineCacheProvider));
});
