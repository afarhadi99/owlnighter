import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/adaptive_back_button.dart';
import '../reading_path/reading_path_controller.dart';

/// The full-screen completion sequence — the payoff beat that replaces the old
/// bottom-sheet celebration. NightSky backdrop, a sparkle burst, a cheering owl
/// that pops in, a rolling XP counter, a "streak extended" banner, and a row of
/// stat cards (XP / accuracy / streak) that reveal in a gentle stagger. Its
/// CONTINUE button navigates back to the reading path and refreshes the plan so
/// the finished node turns green and the next one unlocks.
class CompletionPage extends ConsumerStatefulWidget {
  const CompletionPage({
    super.key,
    required this.planId,
    required this.result,
  });

  final String planId;
  final QuizResult result;

  @override
  ConsumerState<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends ConsumerState<CompletionPage>
    with SingleTickerProviderStateMixin {
  Timer? _streakCue;

  /// The master reveal clock: drives the owl pop-in and the staggered rise-in
  /// of the title, XP, streak banner, stats, and button.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.result.passed) {
      final sfx = ref.read(sfxServiceProvider);
      // Fanfare lands first; the warm streak whoosh follows a beat later.
      sfx.play(SoundEffect.fanfare);
      _streakCue = Timer(const Duration(milliseconds: 500), () {
        sfx.play(SoundEffect.streak);
      });
      // A reward haptic thump — but reduce-motion reads from MediaQuery, which
      // isn't available in initState, so defer to after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !reduceMotionOf(context)) {
          unawaited(HapticFeedback.mediumImpact());
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _reveal.value = 1;
    } else if (!_reveal.isAnimating && _reveal.value == 0) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _streakCue?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    // Refresh the plan so the just-completed node renders green and the next
    // one unlocks; the ?celebrate=1 flag lets the path play the unlock cue.
    ref.invalidate(readingPathControllerProvider(widget.planId));
    context.go(Routes.planCelebrate(widget.planId));
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final streak = result.streak;
    final passed = result.passed;
    final accuracy = result.totalCount == 0
        ? 0
        : ((result.correctCount / result.totalCount) * 100).round();
    final intensity = (streak.currentStreak / 14.0).clamp(0.4, 1.0);

    // CompletionPage manages its own NightSky + burst layering, so it does not
    // use NightScaffold's showSky; it wraps in NightScaffold only for the
    // consistent solid night900 background (no black band). The app-bar leading
    // is a subtle escape hatch — the primary path is CONTINUE, but a user
    // should never be fully stuck (pops when possible, else → library).
    return NightScaffold(
      showSky: false,
      leading: const AdaptiveBackButton(
        fallbackLocation: Routes.library,
        icon: Icons.close_rounded,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: NightSky()),
          if (passed)
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiBurst(autoPlay: true)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Spacer(),
                  // The cheering owl over its streak flame — pops in on a spring.
                  _OwlPopIn(
                    reveal: _reveal,
                    child: SizedBox(
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (passed)
                            Positioned(
                              bottom: 0,
                              child: FlameFlicker(
                                intensity: intensity,
                                size: 92,
                                semanticLabel:
                                    '${streak.currentStreak}-day streak flame',
                              ),
                            ),
                          Align(
                            alignment: passed
                                ? Alignment.topCenter
                                : Alignment.center,
                            child: OwlMascot(
                              state: passed ? OwlState.cheer : OwlState.idle,
                              size: 108,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RiseIn(
                    reveal: _reveal,
                    start: 0.25,
                    end: 0.55,
                    child: Text(
                      passed ? 'Night complete!' : 'Good effort',
                      style: AppType.display,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RiseIn(
                    reveal: _reveal,
                    start: 0.32,
                    end: 0.62,
                    child: Text(
                      passed
                          ? 'You earned tonight\'s reading — and kept the lamp lit.'
                          : 'Keep going — every night counts.',
                      style: AppType.body.copyWith(color: AppColors.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RiseIn(
                    reveal: _reveal,
                    start: 0.4,
                    end: 0.7,
                    child: XpCounter(
                      value: streak.xpGained,
                      prefix: '+',
                      suffix: ' XP',
                      color: AppColors.amber500,
                    ),
                  ),
                  if (passed) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _RiseIn(
                      reveal: _reveal,
                      start: 0.6,
                      end: 0.9,
                      child: _StreakBanner(streak: streak, intensity: intensity),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _RiseIn(
                    reveal: _reveal,
                    start: 0.7,
                    end: 1.0,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'XP',
                            accent: AppColors.amber500,
                            icon: Icons.bolt_rounded,
                            value: Text('+${streak.xpGained}'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatCard(
                            label: 'Accuracy',
                            accent: AppColors.indigo400,
                            icon: Icons.track_changes_rounded,
                            value: Text('$accuracy%'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatCard(
                            label: 'Streak',
                            accent: AppColors.flame500,
                            value: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FlameFlicker(
                                  intensity: intensity,
                                  size: 22,
                                  semanticLabel: 'streak flame',
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text('${streak.currentStreak}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _RiseIn(
                    reveal: _reveal,
                    start: 0.85,
                    end: 1.0,
                    child: ChunkyButton(
                      label: 'Continue',
                      fullWidth: true,
                      variant: ChunkyButtonVariant.success,
                      onPressed: _continue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "streak extended" banner — a lamp-tinted pill with the streak flame and
/// the running night count.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.intensity});

  final StreakState streak;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final n = streak.currentStreak;
    final isBest = n >= streak.longestStreak && n > 1;
    final subtitle = isBest
        ? 'Your longest lamp yet. Sleep well.'
        : 'Keep the lamp lit — one night at a time.';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lamp.withValues(alpha: 0.16),
            AppColors.lampGlow.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lamp.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlameFlicker(
            intensity: intensity,
            size: 30,
            semanticLabel: 'Streak flame',
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 1 ? 'Streak started' : '$n nights in a row',
                  style: AppType.headline.copyWith(color: AppColors.lamp),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pops its [child] in with a gentle spring (scale + settle rotation) over the
/// first slice of the [reveal] clock. Reduced motion shows it in place.
class _OwlPopIn extends StatelessWidget {
  const _OwlPopIn({required this.reveal, required this.child});

  final Animation<double> reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return child;
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) {
        final t = (reveal.value / 0.45).clamp(0.0, 1.0);
        final eased = AppMotion.spring.transform(t);
        final scale = 0.4 + eased * 0.6; // 0.4 → ~1 (overshoots via spring)
        final opacity = (t * 2).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: (1 - t) * -0.12,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// Fades + rises its [child] into place across a [start]..[end] slice of the
/// [reveal] clock, producing the staggered reveal. Reduced motion shows it
/// immediately.
class _RiseIn extends StatelessWidget {
  const _RiseIn({
    required this.reveal,
    required this.start,
    required this.end,
    required this.child,
  });

  final Animation<double> reveal;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return child;
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) {
        final raw = ((reveal.value - start) / (end - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(raw);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
