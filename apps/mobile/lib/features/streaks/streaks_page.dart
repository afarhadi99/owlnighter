import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/motion/motion.dart';
import '../../shared/theme/theme_re_exports.dart';

/// Local streak state. Updated from the latest quiz submit result; persisted
/// server-side, mirrored here for the tab. A real build would hydrate this from
/// a `/me/streak` read on launch — that endpoint isn't in the contract yet.
final streakStateProvider =
    NotifierProvider<StreakStateNotifier, StreakState>(StreakStateNotifier.new);

class StreakStateNotifier extends Notifier<StreakState> {
  @override
  StreakState build() => const StreakState(currentStreak: 0, longestStreak: 0);

  void applyResult(StreakState next) => state = next;
}

/// The streak tab: flame mascot + a progress ring toward the weekly goal.
class StreaksPage extends ConsumerWidget {
  const StreaksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakStateProvider);
    // 7-day weekly goal ring for a simple, legible target.
    final weekProgress = (streak.currentStreak % 7) / 7;

    return Scaffold(
      appBar: AppBar(title: const Text('Streak')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(
              progress: weekProgress == 0 && streak.currentStreak > 0
                  ? 1
                  : weekProgress,
              size: 200,
              strokeWidth: 16,
              color: AppColors.flame500,
              center: StreakFlame(streakCount: streak.currentStreak),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('${streak.currentStreak}-day streak', style: AppType.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Longest: ${streak.longestStreak} days',
              style: AppType.body.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
