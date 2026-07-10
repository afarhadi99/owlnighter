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
    final json = await _post('/v1/books/ground', {
      'title': title,
      if (author != null) 'author': author,
      'locale': locale,
      'candidates': candidates.map((c) => c.toJson()).toList(),
    });
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
  }) async {
    final json = await _post('/v1/plans/generate', {
      'bookId': bookId,
      'goal': goal,
      'experience': experience,
      'pacingMode': pacingMode.wire,
      if (bedtimeLocal != null) 'bedtimeLocal': bedtimeLocal,
      'maxMinutes': maxMinutes,
      'timezone': timezone,
      if (provider != null) 'provider': provider.wire,
    });
    return ReadingPlan.fromJson(json);
  }

  // ---- GET /v1/plans/:id → getPlan ----
  Future<ReadingPlan> getPlan(String planId) async {
    final json = await _get('/v1/plans/$planId');
    return ReadingPlan.fromJson(json);
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

  // ---- transport helpers ----
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<dynamic>(path, data: body);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await _dio.get<dynamic>(path);
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
