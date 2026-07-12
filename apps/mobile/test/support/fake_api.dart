import 'package:owlnighter/services/api/extras_api.dart';

/// A fake [QuizCheckApi] for the per-question feedback loop. Grades an answer
/// as correct iff it equals [answerKey] for that question; returns [correctFor]
/// as the revealed correct answer.
class FakeQuizCheckApi implements QuizCheckApi {
  FakeQuizCheckApi({
    this.answerKey = const {},
    this.explanation,
  });

  /// questionId -> the answer that counts as correct.
  final Map<String, String> answerKey;
  final String? explanation;

  final List<({String questionId, String answer})> calls = [];

  @override
  Future<QuizCheckResult> checkAnswer({
    required String quizId,
    required String questionId,
    required String answer,
  }) async {
    calls.add((questionId: questionId, answer: answer));
    final key = answerKey[questionId] ?? '__correct__';
    return QuizCheckResult(
      correct: answer == key,
      correctAnswer: key,
      explanation: explanation,
    );
  }
}

/// A fake [StatsApi] returning a canned [MyStats].
class FakeStatsApi implements StatsApi {
  FakeStatsApi(this.stats);
  final MyStats stats;
  int calls = 0;

  @override
  Future<MyStats> fetchStats() async {
    calls++;
    return stats;
  }
}

/// Builds a trailing 7-day week ending today; the last [readDays] days are read.
List<StatsDay> fakeWeek({int readDays = 1, int xpPerDay = 20}) {
  final today = DateTime.now();
  return List.generate(7, (i) {
    final date = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 6 - i));
    final read = i >= 7 - readDays;
    return StatsDay(date: date, read: read, xp: read ? xpPerDay : 0);
  });
}
