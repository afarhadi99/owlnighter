import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/extras_api.dart';
import '../../services/api/repository_providers.dart';
import '../../services/icon/app_icon_bridge.dart';
import '../../services/widget/home_widget_bridge.dart';
import '../../shared/mood/owl_mood.dart';
import '../nightly_session/nightly_session_controller.dart';

/// Immutable UI state for the per-question feedback loop.
///
/// Each question moves through two phases:
///  1. **selecting** — the reader picks an option (recorded in [answers]); the
///     CHECK button is enabled.
///  2. **checked** — CHECK graded the answer via `POST /v1/quiz/:id/check`; the
///     result is stored in [checked] and the FeedbackBanner shows. CONTINUE
///     advances (or, on the last question, submits the whole quiz).
@immutable
class QuizUiState {
  const QuizUiState({
    required this.quiz,
    this.currentIndex = 0,
    this.answers = const {},
    this.checked = const {},
    this.checking = false,
    this.submitting = false,
    this.result,
    this.error,
  });

  final QuizInstance quiz;
  final int currentIndex;

  /// questionId -> chosen answer.
  final Map<String, String> answers;

  /// questionId -> instant-feedback verdict (present once CHECK returned).
  final Map<String, QuizCheckResult> checked;

  /// A check request is in flight.
  final bool checking;

  /// The final submit is in flight.
  final bool submitting;

  /// The final scored result (set once the last question is submitted).
  final QuizResult? result;
  final Object? error;

  QuizQuestion get current => quiz.questions[currentIndex];
  int get total => quiz.questions.length;
  bool get isLast => currentIndex == total - 1;

  /// The current question's selected answer, if any.
  String? get currentAnswer => answers[current.id];
  bool get currentAnswered => answers.containsKey(current.id);

  /// The current question's verdict once checked, else null.
  QuizCheckResult? get currentVerdict => checked[current.id];
  bool get currentChecked => checked.containsKey(current.id);

  /// Fills as each question is checked; the header bar pulses as it grows.
  double get progress => total == 0 ? 0 : checked.length / total;

  /// How many checked answers were correct — the local verdict tally used by
  /// the completion sequence's accuracy stat.
  int get correctSoFar => checked.values.where((v) => v.correct).length;

  QuizUiState copyWith({
    int? currentIndex,
    Map<String, String>? answers,
    Map<String, QuizCheckResult>? checked,
    bool? checking,
    bool? submitting,
    QuizResult? result,
    Object? error,
  }) =>
      QuizUiState(
        quiz: quiz,
        currentIndex: currentIndex ?? this.currentIndex,
        answers: answers ?? this.answers,
        checked: checked ?? this.checked,
        checking: checking ?? this.checking,
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
        error: error,
      );
}

class QuizController
    extends AutoDisposeFamilyNotifier<QuizUiState, QuizInstance> {
  @override
  QuizUiState build(QuizInstance arg) => QuizUiState(quiz: arg);

  /// Record a selection. No-op once the current question has been checked
  /// (answers lock in after the verdict shows).
  void answer(String questionId, String value) {
    if (state.checked.containsKey(questionId)) return;
    state = state.copyWith(
      answers: {...state.answers, questionId: value},
    );
  }

  /// Grade the current answer for instant feedback. Returns the verdict (or
  /// null if there was nothing selected / an error). Does NOT record an attempt
  /// server-side — only [submit] does.
  Future<QuizCheckResult?> check() async {
    final answer = state.currentAnswer;
    if (answer == null || state.currentChecked || state.checking) return null;
    state = state.copyWith(checking: true, error: null);
    try {
      final verdict = await ref.read(quizCheckApiProvider).checkAnswer(
            quizId: state.quiz.quizId,
            questionId: state.current.id,
            answer: answer,
          );
      state = state.copyWith(
        checking: false,
        checked: {...state.checked, state.current.id: verdict},
      );
      return verdict;
    } on Exception catch (e) {
      state = state.copyWith(checking: false, error: e);
      return null;
    }
  }

  /// Advance to the next question. Only meaningful once the current question is
  /// checked; the last question submits instead (see [submit]).
  void next() {
    if (!state.isLast && state.currentChecked) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Submit all answers and score. On success the reading is marked complete
  /// and the streak is updated server-side.
  Future<QuizResult?> submit() async {
    if (state.submitting) return state.result;
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
      // Tonight's reading is done — refresh the home-screen widget to its
      // success state with the new streak. Best-effort, never blocks submit.
      unawaited(
        HomeWidgetBridge.publish(
          hasReadToday: true,
          currentStreak: result.streak.currentStreak,
        ),
      );
      unawaited(
        AppIconBridge.publish(
          owlMoodFor(hasReadToday: true, now: DateTime.now()),
        ),
      );
      return result;
    } on Exception catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return null;
    }
  }
}

final quizControllerProvider = AutoDisposeNotifierProviderFamily<QuizController,
    QuizUiState, QuizInstance>(QuizController.new);
