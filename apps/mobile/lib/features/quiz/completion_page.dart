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
import '../reading_path/reading_path_controller.dart';

/// The full-screen completion sequence — the payoff beat that replaces the old
/// bottom-sheet celebration. NightSky backdrop, confetti, a cheering owl, a
/// rolling XP counter, and a row of stat cards (XP / accuracy / streak). Its
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

class _CompletionPageState extends ConsumerState<CompletionPage> {
  Timer? _streakCue;

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
  void dispose() {
    _streakCue?.cancel();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                  SizedBox(
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
                          alignment:
                              passed ? Alignment.topCenter : Alignment.center,
                          child: OwlMascot(
                            state: passed ? OwlState.cheer : OwlState.idle,
                            size: 108,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    passed ? 'Night complete!' : 'Good effort',
                    style: AppType.display,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    passed
                        ? 'You earned tonight\'s reading.'
                        : 'Keep going — every night counts.',
                    style: AppType.body.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  XpCounter(
                    value: streak.xpGained,
                    prefix: '+',
                    suffix: ' XP',
                    color: AppColors.amber500,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
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
                  const Spacer(),
                  ChunkyButton(
                    label: 'Continue',
                    fullWidth: true,
                    variant: ChunkyButtonVariant.success,
                    onPressed: _continue,
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
