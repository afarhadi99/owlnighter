import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/theme_re_exports.dart';
import 'plan_launcher_controller.dart';
import 'reading_path_page.dart';

/// Opens a book's reading path with get-or-create semantics. Tapping a book in
/// the library lands here: it looks up an existing plan first (the reuse fast
/// path) and only generates one when none exists, showing a real full-screen
/// "Crafting your nightly path…" state while the model works — and a retryable
/// error state on failure. It never silently bounces back to the library.
class PlanLauncherPage extends ConsumerWidget {
  const PlanLauncherPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planLauncherProvider(bookId));

    // Once resolved, render the path map directly (loads via getPlan). No
    // navigation hop, so the back button returns straight to the library.
    if (state.isReady) {
      return ReadingPathPage(planId: state.planId!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your reading path')),
      body: state.isError
          ? _LaunchError(
              error: state.error!,
              onRetry: () =>
                  ref.read(planLauncherProvider(bookId).notifier).retry(),
            )
          : _CraftingView(phase: state.phase),
    );
  }
}

/// Full-screen progress while the plan is being resolved or generated. Uses the
/// design-system [ProgressRing]; the ring gently breathes to signal work is
/// happening, collapsing to a static ring under reduced motion.
class _CraftingView extends StatefulWidget {
  const _CraftingView({required this.phase});

  final PlanLaunchPhase phase;

  @override
  State<_CraftingView> createState() => _CraftingViewState();
}

class _CraftingViewState extends State<_CraftingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    // Drive (or freeze) the breathing loop based on the OS motion preference.
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    final generating = widget.phase == PlanLaunchPhase.generating;
    final title =
        generating ? 'Crafting your nightly path…' : 'Finding your path…';
    final subtitle = generating
        ? 'Pacing the chapters into cozy nightly reads — this can take a moment.'
        : 'One sec while we line up tonight’s reading.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = reduce ? 0.7 : 0.12 + 0.8 * _controller.value;
                return ProgressRing(
                  progress: progress,
                  size: 132,
                  center: const Icon(
                    Icons.auto_stories_rounded,
                    size: 40,
                    color: AppColors.indigo400,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppType.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retryable full-screen error — the explicit alternative to the old silent
/// bounce back to the library when generation timed out.
class _LaunchError extends StatelessWidget {
  const _LaunchError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Couldn’t open your path',
              style: AppType.headline.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Building the plan took too long or hit a snag. Your progress is '
              'safe — try again and we’ll pick up where the server left off.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
