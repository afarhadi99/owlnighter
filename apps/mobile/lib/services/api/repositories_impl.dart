import 'package:api_client/api_client.dart';
import 'package:app_core/app_core.dart';
import 'package:offline/offline.dart';

/// Concrete repositories composing the network client with the offline cache.
/// The offline-first posture: reads prefer the network but fall back to the
/// local cache when offline; successful reads warm the cache; mutations that
/// must survive offline are enqueued.

class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({required this.api, required this.cache});
  final OwlnighterApi api;
  final OfflineCache cache;

  @override
  Future<({List<CatalogCandidate> candidates, Book? suggested})> searchBooks({
    required String title,
    String? author,
    String? isbn13,
    String locale = 'en-US',
    int limit = 10,
  }) =>
      api.searchBooks(
        title: title,
        author: author,
        isbn13: isbn13,
        locale: locale,
        limit: limit,
      );

  @override
  Future<GroundedBook> groundBook({
    required String title,
    String? author,
    String locale = 'en-US',
    List<CatalogCandidate> candidates = const [],
  }) =>
      api.groundBook(
        title: title,
        author: author,
        locale: locale,
        candidates: candidates,
      );

  @override
  Future<UserBook> addLibraryBook({
    required String bookId,
    int targetNightlyPages = 10,
    String? preferredReadingTimeLocal,
    String timezone = 'UTC',
  }) async {
    final book = await api.addLibraryBook(
      bookId: bookId,
      targetNightlyPages: targetNightlyPages,
      preferredReadingTimeLocal: preferredReadingTimeLocal,
      timezone: timezone,
    );
    await cache.upsertUserBook(book);
    return book;
  }

  @override
  Future<List<UserBook>> listLibrary() async {
    // Offline-first: serve cache immediately if the network is down.
    try {
      // The API has no list endpoint in the contract yet; the cache is the
      // source of truth for the local library view. When a list endpoint lands
      // this is where we'd refresh + warm the cache.
      return await cache.library();
    } on Exception {
      return cache.library();
    }
  }
}

class PlanRepositoryImpl implements PlanRepository {
  PlanRepositoryImpl({required this.api, required this.cache});
  final OwlnighterApi api;
  final OfflineCache cache;

  @override
  Future<ReadingPlan> generatePlan({
    required String bookId,
    String goal = 'build nightly habit',
    String experience = 'returning',
    PacingMode pacingMode = PacingMode.standard,
    String? bedtimeLocal,
    int maxMinutes = 25,
    String timezone = 'UTC',
    AiProvider? provider,
  }) async {
    final plan = await api.generatePlan(
      bookId: bookId,
      goal: goal,
      experience: experience,
      pacingMode: pacingMode,
      bedtimeLocal: bedtimeLocal,
      maxMinutes: maxMinutes,
      timezone: timezone,
      provider: provider,
    );
    await cache.upsertPlanSteps(plan);
    return plan;
  }

  @override
  Future<ReadingPlan> getPlan(String planId) async {
    try {
      final plan = await api.getPlan(planId);
      await cache.upsertPlanSteps(plan);
      return plan;
    } on ApiException catch (e) {
      // If offline, the caller should degrade to per-step cached content; a
      // full ReadingPlan is not reconstructable from step rows alone, so we
      // rethrow and let the nightly-session flow read the cached step directly.
      if (e.isOffline) rethrow;
      rethrow;
    }
  }
}

class QuizRepositoryImpl implements QuizRepository {
  QuizRepositoryImpl({required this.api, required this.cache, this.syncQueue});
  final OwlnighterApi api;
  final OfflineCache cache;
  final SyncQueue? syncQueue;

  @override
  Future<QuizInstance> generateStepQuiz({
    required String stepId,
    String? userProvidedText,
    int questionCount = 4,
    bool regenerate = false,
  }) async {
    try {
      final quiz = await api.generateStepQuiz(
        stepId: stepId,
        userProvidedText: userProvidedText,
        questionCount: questionCount,
        regenerate: regenerate,
      );
      await cache.cacheQuiz(quiz);
      return quiz;
    } on ApiException catch (e) {
      // Offline: use the prefetched quiz contract if we have one.
      if (e.isOffline) {
        final cached = await cache.quizForStep(stepId);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizAnswer> answers,
  }) =>
      api.submitQuiz(quizId: quizId, answers: answers);
}
