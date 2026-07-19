import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/analytics/analytics.dart';
import '../../services/api/repository_providers.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/adaptive_back_button.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/quiz_mode_badge.dart';
import '../audio/recap_player.dart';
import 'nightly_session_controller.dart';

/// The nightly session screen: shows tonight's reading target, the honesty
/// badge for how trustworthy the quiz will be, an optional recap player, and
/// the entry point into the quiz. This is the top of the core loop:
/// session -> quiz -> streak celebration.
///
/// Wave-2 redesign: a calm, bedtime-focused "Tonight's reading" card that
/// matches the cozy-nocturnal prototype — a sleepy owl beside the serif
/// chapter title, page-range + reading-mode chips, the real honesty badge, a
/// gentle serif quote, key/value rows, the recap player, and the lamp-gold
/// CTA into the quiz. All logic/wiring (startStep, quiz generation, routing)
/// is unchanged.
class NightlySessionPage extends ConsumerStatefulWidget {
  const NightlySessionPage({
    super.key,
    required this.planId,
    required this.stepId,
  });

  final String planId;
  final String stepId;

  @override
  ConsumerState<NightlySessionPage> createState() => _NightlySessionPageState();
}

class _NightlySessionPageState extends ConsumerState<NightlySessionPage> {
  @override
  void initState() {
    super.initState();
    // Opening the session starts (or reuses) the server-side reading session so
    // the streak timer runs. Best-effort: startStep swallows offline failures.
    unawaited(
      ref.read(planRepositoryProvider).startStep(widget.stepId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepAsync = ref.watch(nightlyStepProvider(widget.stepId));
    return NightScaffold(
      title: "Tonight's reading",
      // Always offer a way back to the library even when this screen has no
      // route to pop (e.g. reached via a stack-replacing navigation).
      leading: const AdaptiveBackButton(fallbackLocation: Routes.library),
      // A subtler night sky (fewer stars) so the reading copy stays legible.
      starCount: 24,
      body: AsyncValueView<PlanStep?>(
        value: stepAsync,
        onRetry: () => ref.invalidate(nightlyStepProvider(widget.stepId)),
        data: (step) => step == null
            ? const _MissingStep()
            : _SessionBody(
                planId: widget.planId,
                stepId: widget.stepId,
                step: step,
              ),
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
    final night = step.stepIndex + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A sleepy owl sets the bedtime mood beside tonight's title.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OwlMascot(state: OwlState.sleepy, size: 56),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NIGHT $night',
                      style: AppType.caption.copyWith(
                        color: AppColors.lamp,
                        letterSpacing: 2.4,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(step.title, style: AppType.title),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Page-range + reading-mode chips, plus the real honesty badge.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StepChip(
                icon: Icons.menu_book_rounded,
                label: range,
              ),
              if (step.pageRangeLabel != null && step.chapterHint != null)
                _StepChip(
                  icon: Icons.bookmark_border_rounded,
                  label: step.chapterHint!,
                  tone: _ChipTone.lamp,
                ),
              QuizModeBadge(mode: step.quizMode),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Tonight's reading card: the prompt, a gentle serif quote, and the
          // key/value rows that frame the night.
          _StepCard(step: step, range: range),
          const SizedBox(height: AppSpacing.md),
          RecapPlayer(stepId: stepId),
          const SizedBox(height: AppSpacing.xl),
          ChunkyButton(
            label: gen.isLoading
                ? 'Preparing your quiz…'
                : "I've read it — quiz me",
            icon: gen.isLoading ? null : Icons.auto_stories_rounded,
            fullWidth: true,
            onPressed: gen.isLoading ? null : () => _startQuiz(context, ref),
          ),
          if (gen.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not prepare the quiz: ${gen.error}',
              style: AppType.caption.copyWith(color: AppColors.danger500),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              'Read at your pace. The quiz is a gentle check, not a test.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startQuiz(BuildContext context, WidgetRef ref) async {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
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

/// The cozy "Tonight's reading" card — a soft gradient panel holding the step
/// prompt, a serif quote rule, a divider, and the framing key/value rows.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.range});

  final PlanStep step;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night700, AppColors.night800],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.prompt,
            style: AppType.body.copyWith(color: AppColors.inkMuted, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.md),
          // A gentle serif quote rule — the app's bedtime encouragement.
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.lamp, width: 2),
              ),
            ),
            child: Text(
              'A little reading, every night, keeps the story — and the lamp — alive.',
              style: AppType.body.copyWith(
                color: AppColors.inkMuted,
                fontFamily: AppType.serifFamily,
                fontFamilyFallback: AppType.serifFallback,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.sm),
          _KvRow(label: 'Pages tonight', value: range),
          _KvRow(
            label: 'Reading mode',
            value: _modeLabel(step.quizMode),
            valueColor: AppColors.twilightHi,
          ),
          const _KvRow(
            label: 'Quiz to keep the streak',
            value: 'A gentle check',
            valueColor: AppColors.lamp,
          ),
        ],
      ),
    );
  }

  static String _modeLabel(QuizMode mode) => switch (mode) {
        QuizMode.grounded => 'Grounded in the text',
        QuizMode.preview => 'From the preview',
        QuizMode.userText => 'Your own pages',
        QuizMode.fallback => 'General knowledge',
      };
}

enum _ChipTone { twilight, lamp }

/// A small pill chip for the step meta row (page range, chapter).
class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.icon,
    required this.label,
    this.tone = _ChipTone.twilight,
  });

  final IconData icon;
  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
        tone == _ChipTone.lamp ? AppColors.lamp : AppColors.twilightHi;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single label/value row inside the step card.
class _KvRow extends StatelessWidget {
  const _KvRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.moon,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppType.caption.copyWith(
                color: AppColors.faint,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.caption.copyWith(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
