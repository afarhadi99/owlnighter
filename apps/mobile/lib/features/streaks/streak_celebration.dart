import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';

/// Shows the end-of-loop celebration: a cheering owl over a streak flame,
/// confetti, the new streak count, and XP gained. This is the payoff beat of
/// session -> quiz -> streak. On a passing result it fires the fanfare + streak
/// sound cues; motion (confetti, flame, owl) all honor reduced motion.
Future<void> showStreakCelebration(
  BuildContext context, {
  required QuizResult result,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _CelebrationSheet(result: result),
  );
}

class _CelebrationSheet extends ConsumerStatefulWidget {
  const _CelebrationSheet({required this.result});
  final QuizResult result;

  @override
  ConsumerState<_CelebrationSheet> createState() => _CelebrationSheetState();
}

class _CelebrationSheetState extends ConsumerState<_CelebrationSheet> {
  Timer? _streakCue;

  @override
  void initState() {
    super.initState();
    if (widget.result.passed) {
      final sfx = ref.read(sfxServiceProvider);
      // Fanfare lands first; the warm streak whoosh follows a beat later.
      sfx.play(SoundEffect.fanfare);
      _streakCue = Timer(const Duration(milliseconds: 450), () {
        sfx.play(SoundEffect.streak);
      });
    }
  }

  @override
  void dispose() {
    _streakCue?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final streak = result.streak;
    final passed = result.passed;
    // Map the streak length onto the flame's height/liveliness (caps at 2 wks).
    final intensity = (streak.currentStreak / 14.0).clamp(0.4, 1.0);

    final sheet = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (passed)
                  Positioned(
                    bottom: 0,
                    child: FlameFlicker(
                      intensity: intensity,
                      size: 96,
                      semanticLabel: '${streak.currentStreak}-day streak flame',
                    ),
                  ),
                Align(
                  alignment: passed ? Alignment.topCenter : Alignment.center,
                  child: OwlMascot(
                    state: passed ? OwlState.cheer : OwlState.idle,
                    size: 104,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            passed ? 'Nice reading tonight!' : 'Good effort',
            style: AppType.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${result.correctCount}/${result.totalCount} correct',
            style: AppType.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                icon: Icons.local_fire_department_rounded,
                value: '${streak.currentStreak}',
                label: 'day streak',
                color: AppColors.flame500,
              ),
              _Stat(
                icon: Icons.bolt_rounded,
                value: '+${streak.xpGained}',
                label: 'XP',
                color: AppColors.amber500,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: RewardButton(
              onTap: () {
                ref.read(sfxServiceProvider).play(SoundEffect.tap);
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.indigo500,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Done',
                  style: AppType.label.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!passed) return sheet;

    // Celebrate over the sheet: confetti rains from the top, ignoring taps.
    return Stack(
      children: [
        sheet,
        const Positioned.fill(
          child: IgnorePointer(
            child: ConfettiBurst(autoPlay: true),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppType.title.copyWith(color: color)),
        Text(label, style: AppType.caption.copyWith(color: AppColors.inkMuted)),
      ],
    );
  }
}
