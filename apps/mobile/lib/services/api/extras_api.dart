import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/util/env.dart';
import 'session_provider.dart';

/// Instant per-question feedback returned by `POST /v1/quiz/:id/check`.
///
/// Checking an answer does NOT record an attempt or move the streak — only the
/// final submit does. Mirrors `QuizCheckResponse` in contracts/quiz.ts.
class QuizCheckResult {
  const QuizCheckResult({
    required this.correct,
    required this.correctAnswer,
    this.explanation,
  });

  final bool correct;
  final String correctAnswer;
  final String? explanation;

  factory QuizCheckResult.fromJson(Map<String, dynamic> json) =>
      QuizCheckResult(
        correct: json['correct'] as bool,
        correctAnswer: json['correctAnswer'] as String,
        explanation: json['explanation'] as String?,
      );
}

/// One day in the trailing 7-day window from `GET /v1/me/stats` (oldest first,
/// last entry is today). Mirrors `StatsDay`.
class StatsDay {
  const StatsDay({required this.date, required this.read, required this.xp});

  final DateTime date;
  final bool read;
  final int xp;

  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
        date: DateTime.parse(json['date'] as String),
        read: json['read'] as bool,
        xp: (json['xp'] as num).toInt(),
      );
}

/// The user's aggregate reading stats from `GET /v1/me/stats`. Mirrors
/// `MyStatsResponse`.
class MyStats {
  const MyStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXp,
    required this.xpToday,
    required this.week,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final int xpToday;
  final List<StatsDay> week;

  factory MyStats.fromJson(Map<String, dynamic> json) => MyStats(
        currentStreak: (json['currentStreak'] as num).toInt(),
        longestStreak: (json['longestStreak'] as num).toInt(),
        totalXp: (json['totalXp'] as num).toInt(),
        xpToday: (json['xpToday'] as num).toInt(),
        week: (json['week'] as List<dynamic>)
            .map((e) => StatsDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Grades a single answer for instant feedback. Split out as an interface so
/// the quiz controller can be tested against a fake without a network.
abstract interface class QuizCheckApi {
  Future<QuizCheckResult> checkAnswer({
    required String quizId,
    required String questionId,
    required String answer,
  });
}

/// Reads the caller's aggregate stats. Interface so the streak tab is testable.
abstract interface class StatsApi {
  Future<MyStats> fetchStats();
}

/// A tiny typed client for the two endpoints the hand-written [OwlnighterApi]
/// does not yet cover (quiz check + me/stats). It lives in the app rather than
/// the shared api_client package, but composes the SAME transport: one Dio with
/// the shared [AuthInterceptor] so the bearer token stays live after a refresh.
class ExtrasApi implements QuizCheckApi, StatsApi {
  ExtrasApi({
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

  /// POST /v1/quiz/:id/check — grade a single answer for instant feedback.
  @override
  Future<QuizCheckResult> checkAnswer({
    required String quizId,
    required String questionId,
    required String answer,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/v1/quiz/$quizId/check',
        data: {'questionId': questionId, 'answer': answer},
      );
      return QuizCheckResult.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /v1/me/stats — streaks, XP, and the trailing 7-day week.
  @override
  Future<MyStats> fetchStats() async {
    try {
      final res = await _dio.get<dynamic>('/v1/me/stats');
      return MyStats.fromJson(_asMap(res.data));
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

/// Composition root for the extra endpoints. Reads the bearer lazily from the
/// [SessionController] just like [apiProvider].
final extrasApiProvider = Provider<ExtrasApi>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return ExtrasApi(
    baseUrl: AppEnv.apiBaseUrl,
    tokenProvider: () => session.session?.accessToken,
  );
});

/// Interface-typed views onto the shared [ExtrasApi] so features depend on the
/// narrow capability they use — and tests swap in a fake with
/// `overrideWithValue`.
final quizCheckApiProvider = Provider<QuizCheckApi>(
  (ref) => ref.watch(extrasApiProvider),
);

final statsApiProvider = Provider<StatsApi>(
  (ref) => ref.watch(extrasApiProvider),
);
