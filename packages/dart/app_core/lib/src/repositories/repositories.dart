import '../auth/auth_session.dart';
import '../models/book.dart';
import '../models/enums.dart';
import '../models/plan.dart';
import '../models/quiz.dart';

/// Repository interfaces. The domain depends only on these abstractions; the
/// concrete implementations (api_client + offline drift cache) live in the app
/// composition layer. "Repositories over services": each returns domain models,
/// not transport DTOs.

/// Book discovery + grounding + library membership.
abstract interface class LibraryRepository {
  /// Deterministic catalog search (Google Books + Open Library merge).
  Future<({List<CatalogCandidate> candidates, Book? suggested})> searchBooks({
    required String title,
    String? author,
    String? isbn13,
    String locale = 'en-US',
    int limit = 10,
  });

  /// Gemini search-grounding enrichment / edition reconciliation.
  Future<GroundedBook> groundBook({
    required String title,
    String? author,
    String locale = 'en-US',
    List<CatalogCandidate> candidates = const [],
  });

  /// Add a grounded book to the user's library.
  Future<UserBook> addLibraryBook({
    required String bookId,
    int targetNightlyPages = 10,
    String? preferredReadingTimeLocal,
    String timezone = 'UTC',
  });

  /// The user's current library (offline-first: served from the local cache
  /// when available, refreshed opportunistically).
  Future<List<UserBook>> listLibrary();
}

/// Reading-plan generation + retrieval.
abstract interface class PlanRepository {
  Future<ReadingPlan> generatePlan({
    required String bookId,
    String goal = 'build nightly habit',
    String experience = 'returning',
    PacingMode pacingMode = PacingMode.standard,
    String? bedtimeLocal,
    int maxMinutes = 25,
    String timezone = 'UTC',
    AiProvider? provider,
  });

  Future<ReadingPlan> getPlan(String planId);

  /// Open (or reuse) the reading session for a step. Called when the nightly
  /// session screen is shown. Best-effort: implementations swallow offline
  /// failures so the reader can still work through cached content.
  Future<void> startStep(String stepId);
}

/// Quiz generation + scoring for a plan step.
abstract interface class QuizRepository {
  Future<QuizInstance> generateStepQuiz({
    required String stepId,
    String? userProvidedText,
    int questionCount = 4,
    bool regenerate = false,
  });

  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizAnswer> answers,
  });
}

/// Authentication + session persistence.
abstract interface class AuthRepository {
  /// Restore a persisted session on cold start (from secure storage). Null when
  /// there is no valid session.
  Future<AuthSession?> restore();

  Future<AuthSession> signIn({required String email, required String password});

  Future<AuthSession> signInWithMagicLink(String email);

  /// Exchange a refresh token for a fresh access token.
  Future<AuthSession> refresh(AuthSession current);

  Future<void> signOut();
}
