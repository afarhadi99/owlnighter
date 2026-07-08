import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/analytics/analytics.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/quiz_mode_badge.dart';
import '../audio/recap_player.dart';
import 'nightly_session_controller.dart';

/// The nightly session screen: shows tonight's reading target, the honesty
/// badge for how trustworthy the quiz will be, an optional recap player, and
/// the entry point into the quiz. This is the top of the core loop:
/// session -> quiz -> streak celebration.
class NightlySessionPage extends ConsumerWidget {
  const NightlySessionPage({
    super.key,
    required this.planId,
    required this.stepId,
  });

  final String planId;
  final String stepId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepAsync = ref.watch(nightlyStepProvider(stepId));
    return Scaffold(
      appBar: AppBar(title: const Text("Tonight's reading")),
      body: AsyncValueView<PlanStep?>(
        value: stepAsync,
        onRetry: () => ref.invalidate(nightlyStepProvider(stepId)),
        data: (step) => step == null
            ? const _MissingStep()
            : _SessionBody(planId: planId, stepId: stepId, step: step),
      ),
    );
  }
}

class _MissingStep extends StatelessWidget {
  const _MissingStep();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            "This step hasn't been prefetched yet. Reconnect to load it.",
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _SessionBody extends ConsumerWidget {
  const _SessionBody({
    required this.planId,
    required this.stepId,
    required this.step,
  });

  final String planId;
  final String stepId;
  final PlanStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gen = ref.watch(quizGenControllerProvider);
    final range = step.pageRangeLabel ?? step.chapterHint ?? 'Tonight';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: AppType.title),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: AppColors.indigo400,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                range,
                style: AppType.label.copyWith(
                  color: AppColors.indigo400,
                ),
              ),
              const Spacer(),
              QuizModeBadge(mode: step.quizMode),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(step.prompt, style: AppType.body),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RecapPlayer(stepId: stepId),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: RewardButton(
              onTap: gen.isLoading ? () {} : () => _startQuiz(context, ref),
              child: _StartButton(loading: gen.isLoading),
            ),
          ),
          if (gen.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not prepare the quiz: ${gen.error}',
              style: AppType.caption.copyWith(color: AppColors.danger500),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startQuiz(BuildContext context, WidgetRef ref) async {
    await ref.read(analyticsProvider).sessionStarted(stepId);
    try {
      final quiz =
          await ref.read(quizGenControllerProvider.notifier).generate(stepId);
      if (!context.mounted) return;
      context.push(Routes.quiz(planId, stepId, quiz.quizId));
    } on Exception {
      // Error is surfaced via the controller's AsyncError state.
    }
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.indigo500,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              "I've read it — start quiz",
              style: AppType.label.copyWith(color: Colors.white),
            ),
    );
  }
}
