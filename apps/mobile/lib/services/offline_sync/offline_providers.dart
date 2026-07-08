import 'package:api_client/api_client.dart';
import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline/offline.dart';

import '../api/api_providers.dart';

/// The on-device Drift database. One instance for the app lifetime.
final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  final db = OfflineDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Domain-facing read/write cache over the database.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return OfflineCache(ref.watch(offlineDatabaseProvider));
});

/// The outbound sync queue. Its handler maps queued operation names back to
/// concrete API calls — this is the one place that knows both sides.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final db = ref.watch(offlineDatabaseProvider);
  final api = ref.watch(apiProvider);
  return SyncQueue(
    db: db,
    handler: (op) => _handleSyncOp(api, op),
  );
});

/// Maps a queued [SyncOp] to an API call and classifies the outcome so the
/// queue can decide retry vs drop.
Future<SyncOutcome> _handleSyncOp(OwlnighterApi api, SyncOp op) async {
  try {
    switch (op.operation) {
      case 'submitQuiz':
        final answers = (op.payload['answers'] as List<dynamic>)
            .map(
              (e) => QuizAnswer(
                questionId: (e as Map<String, dynamic>)['questionId'] as String,
                answer: e['answer'] as String,
              ),
            )
            .toList();
        await api.submitQuiz(
          quizId: op.payload['quizId'] as String,
          answers: answers,
        );
      case 'addLibraryBook':
        await api.addLibraryBook(
          bookId: op.payload['bookId'] as String,
          targetNightlyPages: op.payload['targetNightlyPages'] as int? ?? 10,
        );
      case 'registerPushToken':
        await api.registerPushToken(
          token: op.payload['token'] as String,
          platform: op.payload['platform'] as String,
          appVersion: op.payload['appVersion'] as String?,
        );
      default:
        // Unknown op → drop so a stale enqueue can't wedge the queue.
        return SyncOutcome.drop;
    }
    return SyncOutcome.success;
  } on ApiException catch (e) {
    if (e.isOffline) return SyncOutcome.retry;
    // 4xx (except 401) is permanent; 5xx is worth retrying.
    if (e.statusCode != null && e.statusCode! >= 500) return SyncOutcome.retry;
    return SyncOutcome.drop;
  }
}
