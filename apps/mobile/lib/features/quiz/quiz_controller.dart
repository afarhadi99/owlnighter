import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';
import '../nightly_session/nightly_session_controller.dart';

/// Immutable UI state for taking a quiz.
@immutable
class QuizUiState {
  const QuizUiState({
    required this.quiz,
    this.currentIndex = 0,
    this.answers = const {},
    this.submitting = false,
    this.result,
    this.error,
  });

  final QuizInstance quiz;
  final int currentIndex;

  /// questionId -> chosen answer.
  final Map<String, String> answers;
  final bool submitting;
  final QuizResult? result;
  final Object? error;

  QuizQuestion get current => quiz.questions[currentIndex];
  bool get isLast => currentIndex == quiz.questions.length - 1;
  bool get currentAnswered => answers.containsKey(current.id);
  double get progress => (currentIndex + 1) / quiz.questions.length;

  QuizUiState copyWith({
    int? currentIndex,
    Map<String, String>? answers,
    bool? submitting,
    QuizResult? result,
    Object? error,
  }) =>
      QuizUiState(
        quiz: quiz,
        currentIndex: currentIndex ?? this.currentIndex,
        answers: answers ?? this.answers,
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
        error: error,
      );
}

class QuizController extends AutoDisposeFamilyNotifier<QuizUiState, QuizInstance> {
  @override
  QuizUiState build(QuizInstance arg) => QuizUiState(quiz: arg);

  void answer(String questionId, String value) {
    state = state.copyWith(
      answers: {...state.answers, questionId: value},
    );
  }

  void next() {
    if (!state.isLast) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void back() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  /// Submit all answers and score. On success the reading is marked complete
  /// and the streak is updated server-side.
  Future<QuizResult?> submit() async {
    state = state.copyWith(submitting: true, error: null);
    final repo = ref.read(quizRepositoryProvider);
    try {
      final answers = state.answers.entries
          .map((e) => QuizAnswer(questionId: e.key, answer: e.value))
          .toList();
      final result = await repo.submitQuiz(
        quizId: state.quiz.quizId,
        answers: answers,
      );
      state = state.copyWith(submitting: false, result: result);
      // The path map's plan state changed; drop cached plan so it refetches.
      ref.invalidate(nightlyStepProvider);
      return result;
    } on Exception catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return null;
    }
  }
}

final quizControllerProvider = AutoDisposeNotifierProviderFamily<QuizController,
    QuizUiState, QuizInstance>(QuizController.new);
