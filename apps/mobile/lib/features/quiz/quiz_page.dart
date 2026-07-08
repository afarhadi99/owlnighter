import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics/analytics.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../nightly_session/nightly_session_controller.dart';
import '../streaks/streak_celebration.dart';
import 'question_card.dart';
import 'quiz_controller.dart';

/// The quiz screen. Reads the freshly-generated [QuizInstance] from the nightly
/// session controller, swaps between question cards with a slide+fade, and on
/// submit routes into the streak celebration — closing the core loop.
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

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.planId, required this.quiz});
  final String planId;
  final QuizInstance quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider(quiz));
    final controller = ref.read(quizControllerProvider(quiz).notifier);

    // When a result arrives, show the celebration once.
    ref.listen(quizControllerProvider(quiz).select((s) => s.result),
        (prev, next) {
      if (prev == null && next != null) {
        _celebrate(context, ref, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${state.currentIndex + 1} of '
            '${quiz.questions.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: state.progress),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: AnimatedCardSwitcher(
                child: QuestionCard(
                  // Key by index so the switcher animates on question change.
                  key: ValueKey(state.currentIndex),
                  question: state.current,
                  selected: state.answers[state.current.id],
                  onSelect: (v) => controller.answer(state.current.id, v),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _NavRow(state: state, controller: controller),
          ],
        ),
      ),
    );
  }

  Future<void> _celebrate(
    BuildContext context,
    WidgetRef ref,
    QuizResult result,
  ) async {
    await ref
        .read(analyticsProvider)
        .quizSubmitted(result.quizId, passed: result.passed);
    if (!context.mounted) return;
    if (result.passed && result.streak.xpGained > 0) {
      // Fire the XP burst over the current screen for immediate feedback.
      XpBurst.show(context, xp: result.streak.xpGained);
    }
    await showStreakCelebration(context, result: result);
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.state, required this.controller});
  final QuizUiState state;
  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (state.currentIndex > 0)
          TextButton(
            onPressed: controller.back,
            child: const Text('Back'),
          ),
        const Spacer(),
        if (!state.isLast)
          FilledButton(
            onPressed: state.currentAnswered ? controller.next : null,
            child: const Text('Next'),
          )
        else
          FilledButton(
            onPressed: state.currentAnswered && !state.submitting
                ? controller.submit
                : null,
            child: state.submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Finish'),
          ),
      ],
    );
  }
}
