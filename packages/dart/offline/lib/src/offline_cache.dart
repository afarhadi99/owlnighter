import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:drift/drift.dart';

import 'database.dart';

/// Read/write helpers that translate between domain models and Drift rows.
///
/// This is the concrete offline store the app composes with the API to build
/// offline-first repositories. It also implements the prefetch bundle that
/// makes the nightly session work with no network.
class OfflineCache {
  OfflineCache(this.db);

  final OfflineDatabase db;

  // ---- library ----
  Future<void> upsertUserBook(UserBook book, {Book? identity}) async {
    await db.into(db.localUserBooks).insertOnConflictUpdate(
          LocalUserBooksCompanion.insert(
            id: book.id,
            bookId: book.bookId,
            status: book.status.wire,
            currentPage: Value(book.currentPage),
            targetNightlyPages: Value(book.targetNightlyPages),
            bookJson: Value(
              identity == null ? null : jsonEncode(identity.toJson()),
            ),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<UserBook>> library() async {
    final rows = await db.select(db.localUserBooks).get();
    return rows
        .map((r) => UserBook(
              id: r.id,
              bookId: r.bookId,
              status: UserBookStatus.fromWire(r.status),
              currentPage: r.currentPage,
              targetNightlyPages: r.targetNightlyPages,
            ))
        .toList();
  }

  // ---- plan steps ----
  Future<void> upsertPlanSteps(ReadingPlan plan) async {
    await db.batch((batch) {
      for (final step in plan.steps) {
        final state = plan.stateForIndex(step.stepIndex);
        // Skip steps without a persisted state id; nothing to key on offline.
        if (state == null) continue;
        batch.insert(
          db.localPlanSteps,
          LocalPlanStepsCompanion.insert(
            stepId: state.stepId,
            planId: plan.planId,
            stepIndex: step.stepIndex,
            status: state.status.wire,
            stepJson: jsonEncode(step.toJson()),
            unlocksAt: Value(state.unlocksAt),
            ttsAssetId: Value(state.ttsAssetId),
            updatedAt: DateTime.now(),
          ),
          onConflict: DoUpdate((_) => LocalPlanStepsCompanion(
                status: Value(state.status.wire),
                stepJson: Value(jsonEncode(step.toJson())),
                unlocksAt: Value(state.unlocksAt),
                ttsAssetId: Value(state.ttsAssetId),
                updatedAt: Value(DateTime.now()),
              )),
        );
      }
    });
  }

  Future<PlanStep?> planStep(String stepId) async {
    final row = await (db.select(db.localPlanSteps)
          ..where((t) => t.stepId.equals(stepId)))
        .getSingleOrNull();
    if (row == null) return null;
    return PlanStep.fromJson(
      jsonDecode(row.stepJson) as Map<String, dynamic>,
    );
  }

  // ---- quiz ----
  Future<void> cacheQuiz(QuizInstance quiz) async {
    await db.into(db.localQuizInstances).insertOnConflictUpdate(
          LocalQuizInstancesCompanion.insert(
            quizId: quiz.quizId,
            stepId: quiz.stepId,
            quizMode: quiz.quizMode.wire,
            quizJson: jsonEncode(quiz.toJson()),
            fetchedAt: DateTime.now(),
          ),
        );
  }

  Future<QuizInstance?> quizForStep(String stepId) async {
    final row = await (db.select(db.localQuizInstances)
          ..where((t) => t.stepId.equals(stepId))
          ..orderBy([(t) => OrderingTerm.desc(t.fetchedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return QuizInstance.fromJson(
      jsonDecode(row.quizJson) as Map<String, dynamic>,
    );
  }

  // ---- audio ----
  Future<void> cacheAudio({
    required String assetKey,
    required String localPath,
    String? assetId,
    String? stepId,
    int? durationMs,
    int? sizeBytes,
  }) async {
    await db.into(db.localAudioCache).insertOnConflictUpdate(
          LocalAudioCacheCompanion.insert(
            assetKey: assetKey,
            assetId: Value(assetId),
            stepId: Value(stepId),
            localPath: localPath,
            durationMs: Value(durationMs),
            sizeBytes: Value(sizeBytes),
            cachedAt: DateTime.now(),
          ),
        );
  }

  Future<String?> audioPathForStep(String stepId) async {
    final row = await (db.select(db.localAudioCache)
          ..where((t) => t.stepId.equals(stepId))
          ..limit(1))
        .getSingleOrNull();
    return row?.localPath;
  }

  // ---- push inbox ----
  Future<void> recordPush({
    required String messageId,
    String? title,
    String? body,
    String? deepLink,
    Map<String, dynamic>? data,
  }) async {
    await db.into(db.localPushInbox).insertOnConflictUpdate(
          LocalPushInboxCompanion.insert(
            messageId: messageId,
            title: Value(title),
            body: Value(body),
            deepLink: Value(deepLink),
            dataJson: Value(data == null ? null : jsonEncode(data)),
            receivedAt: DateTime.now(),
          ),
        );
  }

  // ---- analytics ----
  Future<void> logEvent(String eventType, Map<String, dynamic> payload) async {
    await db.into(db.localSessionEvents).insert(
          LocalSessionEventsCompanion.insert(
            eventType: eventType,
            payloadJson: jsonEncode(payload),
            occurredAt: DateTime.now(),
          ),
        );
  }
}
