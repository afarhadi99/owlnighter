// TODO: replace with OpenAPI-generated dart-dio client from
// packages/ts/contracts/openapi.json. This hand-written client mirrors the
// ENDPOINTS registry in contracts/endpoints.ts exactly (paths, methods, and
// request/response shapes) so the swap is mechanical when codegen is wired up.

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Typed HTTP client for the owlnighter API. One method per endpoint in the
/// contract's ENDPOINTS registry. All methods throw [ApiException] on failure.
class OwlnighterApi {
  OwlnighterApi({
    required String baseUrl,
    required String? Function() tokenProvider,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..contentType = 'application/json'
      ..responseType = ResponseType.json;
    _dio.interceptors.add(AuthInterceptor(tokenProvider: tokenProvider));
  }

  final Dio _dio;

  // ---- POST /v1/books/search → searchBooks ----
  Future<({List<CatalogCandidate> candidates, Book? suggested})> searchBooks({
    required String title,
    String? author,
    String? isbn13,
    String locale = 'en-US',
    int limit = 10,
  }) async {
    final json = await _post('/v1/books/search', {
      'title': title,
      if (author != null) 'author': author,
      if (isbn13 != null) 'isbn13': isbn13,
      'locale': locale,
      'limit': limit,
    });
    final candidates = (json['candidates'] as List<dynamic>)
        .map((e) => CatalogCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
    final suggested = json['suggested'] == null
        ? null
        : Book.fromJson(json['suggested'] as Map<String, dynamic>);
    return (candidates: candidates, suggested: suggested);
  }

  // ---- POST /v1/books/ground → groundBook ----
  Future<GroundedBook> groundBook({
    required String title,
    String? author,
    String locale = 'en-US',
    List<CatalogCandidate> candidates = const [],
  }) async {
    final json = await _post(
      '/v1/books/ground',
      {
        'title': title,
        if (author != null) 'author': author,
        'locale': locale,
        'candidates': candidates.map((c) => c.toJson()).toList(),
      },
      // Gemini search-grounding is slow; override the default receiveTimeout
      // for this one call so it doesn't abort mid-flight.
      options: Options(receiveTimeout: _aiReceiveTimeout),
    );
    return GroundedBook.fromJson(json);
  }

  // ---- GET /v1/library/books → listLibraryBooks ----
  Future<List<UserBook>> listLibraryBooks() async {
    final json = await _get('/v1/library/books');
    return (json['books'] as List<dynamic>)
        .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- POST /v1/library/books → addLibraryBook ----
  Future<UserBook> addLibraryBook({
    required String bookId,
    int targetNightlyPages = 10,
    String? preferredReadingTimeLocal,
    String timezone = 'UTC',
  }) async {
    final json = await _post('/v1/library/books', {
      'bookId': bookId,
      'targetNightlyPages': targetNightlyPages,
      if (preferredReadingTimeLocal != null)
        'preferredReadingTimeLocal': preferredReadingTimeLocal,
      'timezone': timezone,
    });
    return UserBook.fromJson(json);
  }

  // ---- GET /v1/plans?bookId= → listPlans ----
  /// List the caller's plans for [bookId] (newest planVersion first). Cheap
  /// summaries only; the full plan is loaded on tap via [getPlan]. Enables
  /// get-or-create so opening a book never regenerates a plan needlessly.
  Future<List<PlanSummary>> listPlans({required String bookId}) async {
    final json = await _get('/v1/plans', query: {'bookId': bookId});
    return (json['plans'] as List<dynamic>)
        .map((e) => PlanSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- POST /v1/plans/generate → generatePlan ----
  Future<ReadingPlan> generatePlan({
    required String bookId,
    String goal = 'build nightly habit',
    String experience = 'returning',
    PacingMode pacingMode = PacingMode.standard,
    String? bedtimeLocal,
    int maxMinutes = 25,
    String timezone = 'UTC',
    AiProvider? provider,
    PlanIfExists ifExists = PlanIfExists.reuse,
  }) async {
    final json = await _post(
      '/v1/plans/generate',
      {
        'bookId': bookId,
        'goal': goal,
        'experience': experience,
        'pacingMode': pacingMode.wire,
        if (bedtimeLocal != null) 'bedtimeLocal': bedtimeLocal,
        'maxMinutes': maxMinutes,
        'timezone': timezone,
        if (provider != null) 'provider': provider.wire,
        'ifExists': ifExists.wire,
      },
      // Plan authoring can take ~1 minute on the model; override the default
      // receiveTimeout so the request survives a slow generation.
      options: Options(receiveTimeout: _aiReceiveTimeout),
    );
    return ReadingPlan.fromJson(json);
  }

  // ---- GET /v1/plans/:id → getPlan ----
  Future<ReadingPlan> getPlan(String planId) async {
    final json = await _get('/v1/plans/$planId');
    return ReadingPlan.fromJson(json);
  }

  // ---- POST /v1/steps/:id/start → startStep ----
  /// Opens (or reuses) a reading session for a step. Called when the nightly
  /// screen is opened so the server can time the session. Body is empty; the
  /// step id is in the path.
  Future<StepSession> startStep(String stepId) async {
    final json = await _post('/v1/steps/$stepId/start', const {});
    return StepSession.fromJson(json);
  }

  // ---- POST /v1/steps/:id/quiz → generateStepQuiz ----
  Future<QuizInstance> generateStepQuiz({
    required String stepId,
    String? userProvidedText,
    int questionCount = 4,
    bool regenerate = false,
  }) async {
    final json = await _post('/v1/steps/$stepId/quiz', {
      if (userProvidedText != null) 'userProvidedText': userProvidedText,
      'questionCount': questionCount,
      'regenerate': regenerate,
    });
    return QuizInstance.fromJson(json);
  }

  // ---- POST /v1/quiz/:id/submit → submitQuiz ----
  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizAnswer> answers,
  }) async {
    final json = await _post('/v1/quiz/$quizId/submit', {
      'answers': answers.map((a) => a.toJson()).toList(),
    });
    return QuizResult.fromJson(json);
  }

  // ---- POST /v1/auth/validate-referral-code → validateReferralCode ----
  /// Checks a referral code without consuming it — for live feedback as the
  /// user types, before they submit. Public endpoint (no bearer token
  /// required); the authoritative check happens server-side at activation.
  Future<({bool valid, String? reason})> validateReferralCode(
    String code,
  ) async {
    final json = await _post('/v1/auth/validate-referral-code', {
      'code': code,
    });
    return (
      valid: json['valid'] as bool,
      reason: json['reason'] as String?,
    );
  }

  // ---- GET /v1/auth/status → getAuthStatus ----
  /// Whether the caller's Supabase session has an activated (referral-code
  /// redeemed) `profiles` row yet.
  Future<bool> getAuthStatus() async {
    final json = await _get('/v1/auth/status');
    return json['activated'] as bool;
  }

  // ---- POST /v1/auth/activate → activateAccount ----
  /// Atomically consumes [referralCode] and creates the caller's `profiles`
  /// row. Idempotent — safe to call again for an already-activated user.
  Future<ActivatedProfile> activateAccount({
    required String referralCode,
    String? displayName,
  }) async {
    final json = await _post('/v1/auth/activate', {
      'referralCode': referralCode,
      if (displayName != null) 'displayName': displayName,
    });
    return ActivatedProfile.fromJson(json);
  }

  // ---- POST /v1/push/register → registerPushToken (no response body) ----
  Future<void> registerPushToken({
    required String token,
    required String platform, // ios | android | web
    String? appVersion,
  }) async {
    await _post('/v1/push/register', {
      'token': token,
      'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
    });
  }

  // ---- POST /v1/tts/generate → generateTts ----
  Future<TtsAsset> generateTts({
    required String text,
    String voiceModel = 'aura-2-thalia-en',
    double? speakingRate,
    String locale = 'en',
    String? stepId,
  }) async {
    final json = await _post('/v1/tts/generate', {
      'text': text,
      'voiceModel': voiceModel,
      if (speakingRate != null) 'speakingRate': speakingRate,
      'locale': locale,
      if (stepId != null) 'stepId': stepId,
    });
    return TtsAsset.fromJson(json);
  }

  // Generous per-call receiveTimeout for the AI-backed endpoints (plan
  // generation, book grounding). Model calls can take ~1 minute, which exceeds
  // the default 30s receiveTimeout — without this the app would abort mid-flight
  // even though the server persisted the result. Applied per-call via [Options]
  // so ordinary endpoints keep their tight defaults.
  static const Duration _aiReceiveTimeout = Duration(seconds: 180);

  // ---- transport helpers ----
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Options? options,
  }) async {
    try {
      final res = await _dio.post<dynamic>(path, data: body, options: options);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const {};
    return Map<String, dynamic>.from(data as Map);
  }
}

/// TTS asset descriptor returned by generateTts. Mirrors `TtsGenerateResponse`.
/// Kept here (not app_core) because it is a transport-shaped result the audio
/// service consumes directly.
class TtsAsset {
  const TtsAsset({
    required this.assetId,
    required this.assetKey,
    required this.cached,
    required this.storagePath,
    this.durationMs,
  });

  final String assetId;
  final String assetKey;
  final bool cached;
  final String storagePath;
  final int? durationMs;

  factory TtsAsset.fromJson(Map<String, dynamic> json) => TtsAsset(
        assetId: json['assetId'] as String,
        assetKey: json['assetKey'] as String,
        cached: json['cached'] as bool,
        storagePath: json['storagePath'] as String,
        durationMs: json['durationMs'] as int?,
      );
}

/// The caller's profile just after redeeming a referral code. Mirrors
/// `ActivateAccountResponse`.
class ActivatedProfile {
  const ActivatedProfile({
    required this.id,
    required this.displayName,
    required this.isAdmin,
  });

  final String id;
  final String? displayName;
  final bool isAdmin;

  factory ActivatedProfile.fromJson(Map<String, dynamic> json) =>
      ActivatedProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String?,
        isAdmin: json['isAdmin'] as bool,
      );
}

/// A reading session opened for a step. Mirrors `StepStartResponse`.
class StepSession {
  const StepSession({
    required this.sessionId,
    required this.stepId,
    required this.startedAt,
  });

  final String sessionId;
  final String stepId;
  final DateTime startedAt;

  factory StepSession.fromJson(Map<String, dynamic> json) => StepSession(
        sessionId: json['sessionId'] as String,
        stepId: json['stepId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
      );
}
