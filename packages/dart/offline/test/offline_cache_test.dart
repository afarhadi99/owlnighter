import 'package:app_core/app_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline/offline.dart';

/// OfflineCache read/write against an in-memory sqlite (NativeDatabase.memory),
/// so the prefetch bundle that makes the nightly session work offline is
/// exercised end-to-end without a device.
void main() {
  late OfflineDatabase db;
  late OfflineCache cache;

  setUp(() {
    db = OfflineDatabase(NativeDatabase.memory());
    cache = OfflineCache(db);
  });

  tearDown(() => db.close());

  group('library', () {
    test('upsert persists the enriched title/author and reads it back',
        () async {
      const book = UserBook(
        id: 'ub1',
        bookId: '3ce25e75-aaaa',
        status: UserBookStatus.active,
        currentPage: 12,
        targetNightlyPages: 10,
        title: 'The Hobbit',
        authors: ['J.R.R. Tolkien'],
        coverUrl: 'https://example.com/h.jpg',
        groundingStatus: GroundingStatus.grounded,
        pageCount: 310,
      );
      await cache.upsertUserBook(book);

      final lib = await cache.library();
      expect(lib, hasLength(1));
      final read = lib.single;
      expect(read.displayTitle, 'The Hobbit');
      expect(read.authorLine, 'J.R.R. Tolkien');
      expect(read.groundingStatus, GroundingStatus.grounded);
      expect(read.currentPage, 12);
    });

    test('upsert is idempotent on id (updates, not duplicates)', () async {
      const v1 = UserBook(
        id: 'ub1',
        bookId: 'b1',
        status: UserBookStatus.active,
        title: 'Draft',
      );
      const v2 = UserBook(
        id: 'ub1',
        bookId: 'b1',
        status: UserBookStatus.paused,
        title: 'Final',
      );
      await cache.upsertUserBook(v1);
      await cache.upsertUserBook(v2);

      final lib = await cache.library();
      expect(lib, hasLength(1));
      expect(lib.single.title, 'Final');
      expect(lib.single.status, UserBookStatus.paused);
    });

    test('a bare Book identity payload falls back to flat columns', () async {
      const identity = Book(
        canonicalTitle: 'Ignored For Title',
        authors: ['A'],
        confidence: 0.9,
      );
      const book = UserBook(
        id: 'ub2',
        bookId: 'bbbb1234',
        status: UserBookStatus.active,
      );
      // identity has no `id`/`status`, so library() must reconstruct from cols.
      await cache.upsertUserBook(book, identity: identity);

      final read = (await cache.library()).single;
      expect(read.id, 'ub2');
      expect(read.status, UserBookStatus.active);
      expect(read.displayTitle, 'Book bbbb1234');
    });
  });

  group('plan steps', () {
    ReadingPlan planWith({required List<int> statefulIndexes}) {
      final steps = [
        for (var i = 0; i < 3; i++)
          PlanStep(
            stepIndex: i,
            title: 'Night ${i + 1}',
            quizMode: QuizMode.grounded,
            prompt: 'read $i',
            confidence: 0.9,
            pageStart: i * 10 + 1,
            pageEnd: i * 10 + 10,
          ),
      ];
      final states = [
        for (final i in statefulIndexes)
          PlanStepState(
            stepId: 's$i',
            stepIndex: i,
            status: i == 0 ? StepStatus.available : StepStatus.locked,
          ),
      ];
      return ReadingPlan(
        planId: 'p1',
        bookId: 'b1',
        provider: AiProvider.gemini,
        providerModel: 'm',
        planVersion: 1,
        pacingMode: PacingMode.standard,
        nightlyGoalPages: 10,
        startsOn: DateTime.utc(2026, 7, 10),
        steps: steps,
        stepStates: states,
      );
    }

    test('upsert persists steps keyed by stepId and reads one back', () async {
      await cache.upsertPlanSteps(planWith(statefulIndexes: [0, 1, 2]));
      final step = await cache.planStep('s1');
      expect(step, isNotNull);
      expect(step!.stepIndex, 1);
      expect(step.title, 'Night 2');
      expect(step.pageRangeLabel, 'pp. 11–20');
    });

    test('steps without a persisted state id are skipped', () async {
      await cache.upsertPlanSteps(planWith(statefulIndexes: [0]));
      expect(await cache.planStep('s0'), isNotNull);
      expect(await cache.planStep('s1'), isNull);
    });

    test('planStep returns null for an unknown id', () async {
      expect(await cache.planStep('missing'), isNull);
    });
  });

  group('quiz', () {
    QuizInstance quiz(String id, {String step = 's1'}) => QuizInstance(
          quizId: id,
          stepId: step,
          quizMode: QuizMode.grounded,
          questions: const [
            QuizQuestion(
              id: 'q1',
              kind: QuizQuestionKind.trueFalse,
              prompt: 'p',
              quizMode: QuizMode.grounded,
            ),
          ],
          generatedByProvider: AiProvider.groq,
          generatedByModel: 'qwen',
          confidence: 0.8,
        );

    test('cache + read round-trips the quiz contract', () async {
      await cache.cacheQuiz(quiz('qi1'));
      final read = await cache.quizForStep('s1');
      expect(read, isNotNull);
      expect(read!.quizId, 'qi1');
      expect(read.questions, hasLength(1));
    });

    test('quizForStep returns the most recently fetched instance', () async {
      await cache.cacheQuiz(quiz('old'));
      // Drift persists DateTime at second granularity, so cross a full second
      // to make the fetchedAt ordering deterministic.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await cache.cacheQuiz(quiz('new'));
      final read = await cache.quizForStep('s1');
      expect(read!.quizId, 'new');
    });

    test('quizForStep is null when nothing is cached for the step', () async {
      expect(await cache.quizForStep('nope'), isNull);
    });
  });

  group('audio', () {
    test('cache + resolve local path by step', () async {
      await cache.cacheAudio(
        assetKey: 'hash1',
        localPath: '/tmp/recap.mp3',
        stepId: 's1',
        durationMs: 1000,
      );
      expect(await cache.audioPathForStep('s1'), '/tmp/recap.mp3');
      expect(await cache.audioPathForStep('other'), isNull);
    });
  });

  group('misc sinks', () {
    test('recordPush and logEvent write without error', () async {
      await cache.recordPush(
        messageId: 'm1',
        title: 't',
        body: 'b',
        deepLink: 'readingpath://plan/p1/step/s1',
        data: {'k': 'v'},
      );
      await cache.logEvent('session_started', {'stepId': 's1'});
      // Both tables should now hold a row.
      final pushRows = await db.select(db.localPushInbox).get();
      final eventRows = await db.select(db.localSessionEvents).get();
      expect(pushRows, hasLength(1));
      expect(eventRows, hasLength(1));
    });
  });
}
