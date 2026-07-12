import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/analytics/analytics.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../nightly_session/nightly_session_controller.dart';
import 'question_card.dart';
import 'quiz_controller.dart';

/// The quiz screen — the per-question feedback loop. Reads the freshly-generated
/// [QuizInstance] from the nightly session controller, shows one question at a
/// time with a JuicyProgressBar header, grades each answer for instant feedback
/// (FeedbackBanner slides up), and on the last question submits and routes into
/// the full-screen completion sequence.
class QuizPage extends ConsumerWidget {
  const QuizPage({
    super.key,
    required this.planId,
    required this.stepId,
    required this.quizId,
  });

  final String planId;
  final String stepId;
  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gen = ref.watch(quizGenControllerProvider).valueOrNull;
    // Guard: the quiz must have been generated in the session before we got here.
    if (gen == null || gen.quizId != quizId) {
      return const Scaffold(
        body: Center(child: Text('Quiz expired. Reopen from the session.')),
      );
    }
    return _QuizBody(planId: planId, quiz: gen);
  }
}

class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.planId, required this.quiz});
  final String planId;
  final QuizInstance quiz;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody> {
  QuizInstance get quiz => widget.quiz;

  QuizController get _controller =>
      ref.read(quizControllerProvider(quiz).notifier);

  Future<void> _check() async {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    final verdict = await _controller.check();
    if (verdict == null) return;
    ref
        .read(sfxServiceProvider)
        .play(verdict.correct ? SoundEffect.correct : SoundEffect.wrong);
  }

  Future<void> _continue() async {
    final state = ref.read(quizControllerProvider(quiz));
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    if (!state.isLast) {
      _controller.next();
      return;
    }
    // Last question: submit the whole quiz, then hand off to the completion
    // sequence which owns the payoff + the navigate-back-and-refresh.
    final result = await _controller.submit();
    if (result == null || !mounted) return;
    await ref
        .read(analyticsProvider)
        .quizSubmitted(result.quizId, passed: result.passed);
    if (!mounted) return;
    context.go(Routes.complete(widget.planId), extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizControllerProvider(quiz));

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${state.currentIndex + 1} of ${state.total}'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: JuicyProgressBar(
                value: state.progress,
                segments: state.total,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: AnimatedCardSwitcher(
                  child: QuestionCard(
                    // Key by index so the switcher animates on question change.
                    key: ValueKey(state.currentIndex),
                    question: state.current,
                    selected: state.currentAnswer,
                    verdict: state.currentVerdict,
                    onSelect: (v) {
                      ref.read(sfxServiceProvider).play(SoundEffect.tap);
                      _controller.answer(state.current.id, v);
                    },
                  ),
                ),
              ),
            ),
            _ActionArea(
              state: state,
              onCheck: _check,
              onContinue: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom action area: a CHECK button while selecting, swapped for a
/// FeedbackBanner (with a CONTINUE/FINISH button) once the answer is checked.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.state,
    required this.onCheck,
    required this.onContinue,
  });

  final QuizUiState state;
  final Future<void> Function() onCheck;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final verdict = state.currentVerdict;
    if (verdict == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ChunkyButton(
          label: state.checking ? 'Checking…' : 'Check',
          fullWidth: true,
          onPressed: state.currentAnswered && !state.checking
              ? () {
                  onCheck();
                }
              : null,
        ),
      );
    }

    final isCorrect = verdict.correct;
    final continueLabel = state.isLast ? 'Finish' : 'Continue';
    return FeedbackBanner(
      kind: isCorrect ? FeedbackKind.success : FeedbackKind.error,
      title: isCorrect ? _successTitle : 'Not quite',
      correctAnswer: isCorrect ? null : verdict.correctAnswer,
      action: ChunkyButton(
        label: state.submitting ? 'Finishing…' : continueLabel,
        fullWidth: true,
        variant: isCorrect
            ? ChunkyButtonVariant.success
            : ChunkyButtonVariant.danger,
        onPressed: state.submitting
            ? null
            : () {
                onContinue();
              },
      ),
    );
  }

  static const _successTitle = 'Nicely done!';
}
