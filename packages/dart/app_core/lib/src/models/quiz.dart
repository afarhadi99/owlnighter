import 'package:meta/meta.dart';

import 'enums.dart';

/// A single quiz question. The answer key stays server-side until scoring.
/// Mirrors `QuizQuestion` in contracts/quiz.ts.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.quizMode,
    this.options,
    this.sourceCitationIndex,
  });

  final String id;
  final QuizQuestionKind kind;
  final String prompt;
  final QuizMode quizMode;
  final List<String>? options;
  final int? sourceCitationIndex;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as String,
        kind: QuizQuestionKind.fromWire(json['kind'] as String),
        prompt: json['prompt'] as String,
        quizMode: QuizMode.fromWire(json['quizMode'] as String),
        options: (json['options'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        sourceCitationIndex: json['sourceCitationIndex'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.wire,
        'prompt': prompt,
        'quizMode': quizMode.wire,
        if (options != null) 'options': options,
        if (sourceCitationIndex != null)
          'sourceCitationIndex': sourceCitationIndex,
      };
}

/// A generated quiz for a step. Mirrors `QuizInstance`.
@immutable
class QuizInstance {
  const QuizInstance({
    required this.quizId,
    required this.stepId,
    required this.quizMode,
    required this.questions,
    required this.generatedByProvider,
    required this.generatedByModel,
    required this.confidence,
  });

  final String quizId;
  final String stepId;
  final QuizMode quizMode;
  final List<QuizQuestion> questions;
  final AiProvider generatedByProvider;
  final String generatedByModel;
  final double confidence;

  factory QuizInstance.fromJson(Map<String, dynamic> json) => QuizInstance(
        quizId: json['quizId'] as String,
        stepId: json['stepId'] as String,
        quizMode: QuizMode.fromWire(json['quizMode'] as String),
        questions: (json['questions'] as List<dynamic>)
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        generatedByProvider:
            AiProvider.fromWire(json['generatedByProvider'] as String),
        generatedByModel: json['generatedByModel'] as String,
        confidence: (json['confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'quizId': quizId,
        'stepId': stepId,
        'quizMode': quizMode.wire,
        'questions': questions.map((q) => q.toJson()).toList(),
        'generatedByProvider': generatedByProvider.wire,
        'generatedByModel': generatedByModel,
        'confidence': confidence,
      };
}

/// A reader's answer to one question.
@immutable
class QuizAnswer {
  const QuizAnswer({required this.questionId, required this.answer});
  final String questionId;
  final String answer;

  Map<String, dynamic> toJson() => {'questionId': questionId, 'answer': answer};
}

/// Per-question grading returned after submit.
@immutable
class QuizQuestionResult {
  const QuizQuestionResult({
    required this.questionId,
    required this.correct,
    required this.correctAnswer,
    this.explanation,
  });

  final String questionId;
  final bool correct;
  final String correctAnswer;
  final String? explanation;

  factory QuizQuestionResult.fromJson(Map<String, dynamic> json) =>
      QuizQuestionResult(
        questionId: json['questionId'] as String,
        correct: json['correct'] as bool,
        correctAnswer: json['correctAnswer'] as String,
        explanation: json['explanation'] as String?,
      );
}

/// Result of submitting a quiz, including streak delta. Mirrors
/// `QuizSubmitResponse`.
@immutable
class QuizResult {
  const QuizResult({
    required this.quizId,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.markedComplete,
    required this.perQuestion,
    required this.streak,
  });

  final String quizId;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final bool markedComplete;
  final List<QuizQuestionResult> perQuestion;
  final StreakState streak;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        quizId: json['quizId'] as String,
        correctCount: json['correctCount'] as int,
        totalCount: json['totalCount'] as int,
        passed: json['passed'] as bool,
        markedComplete: json['markedComplete'] as bool,
        perQuestion: (json['perQuestion'] as List<dynamic>)
            .map((e) => QuizQuestionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        streak: StreakState.fromSubmitJson(
          json['streak'] as Map<String, dynamic>,
        ),
      );
}

/// Streak + XP state. Sourced from the `streak` object of a submit response;
/// also used standalone for the streaks feature.
@immutable
class StreakState {
  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    this.xpGained = 0,
    this.totalXp,
  });

  final int currentStreak;
  final int longestStreak;

  /// XP earned in the most recent event (from submit).
  final int xpGained;

  /// Lifetime XP, when known.
  final int? totalXp;

  factory StreakState.fromSubmitJson(Map<String, dynamic> json) => StreakState(
        currentStreak: json['currentStreak'] as int,
        longestStreak: json['longestStreak'] as int,
        xpGained: json['xpGained'] as int? ?? 0,
      );

  bool get isActive => currentStreak > 0;
}
