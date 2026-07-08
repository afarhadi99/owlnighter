import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/theme_re_exports.dart';

/// Shows the end-of-loop celebration: the streak flame mascot, the new streak
/// count, and XP gained. This is the payoff beat of session -> quiz -> streak.
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

class _CelebrationSheet extends StatelessWidget {
  const _CelebrationSheet({required this.result});
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final streak = result.streak;
    final passed = result.passed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreakFlame(streakCount: streak.currentStreak, size: 120),
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
              onTap: () => Navigator.of(context).pop(),
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
