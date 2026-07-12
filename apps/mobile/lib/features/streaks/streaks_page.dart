import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/extras_api.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';

/// Hydrates the streak tab from `GET /v1/me/stats` on open. Auto-disposes so it
/// refetches each time the tab is shown (e.g. after finishing a night).
final myStatsProvider = FutureProvider.autoDispose<MyStats>((ref) async {
  return ref.watch(statsApiProvider).fetchStats();
});

/// The streak tab: a big flame + current streak, longest / total-XP stat cards,
/// and a 7-day week row. Our own night-sky layout in the game-app pattern.
class StreaksPage extends ConsumerWidget {
  const StreaksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    return NightScaffold(
      title: 'Streak',
      starCount: 28,
      body: AsyncValueView<MyStats>(
        value: stats,
        onRetry: () => ref.invalidate(myStatsProvider),
        data: (s) => _StatsBody(stats: s),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final MyStats stats;

  @override
  Widget build(BuildContext context) {
    final intensity = (stats.currentStreak / 14.0).clamp(0.4, 1.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Hero flame + current streak.
          Center(
            child: Column(
              children: [
                FlameFlicker(
                  intensity: intensity,
                  size: 140,
                  semanticLabel: '${stats.currentStreak}-day streak flame',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${stats.currentStreak}',
                  style: AppType.display.copyWith(color: AppColors.flame500),
                ),
                Text(
                  'day streak',
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Longest',
                  accent: AppColors.amber500,
                  icon: Icons.emoji_events_rounded,
                  value: Text('${stats.longestStreak}'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  label: 'Total XP',
                  accent: AppColors.indigo400,
                  icon: Icons.bolt_rounded,
                  value: Text('${stats.totalXp}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('This week', style: AppType.headline),
          const SizedBox(height: AppSpacing.md),
          _WeekRow(week: stats.week),
        ],
      ),
    );
  }
}

/// A row of seven day-initial bubbles: filled green when read that day, today
/// gets an indigo ring.
class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week});
  final List<StatsDay> week;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = week.isEmpty ? null : week.last.date;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in week)
          _DayBubble(
            // ISO weekday: Mon=1 .. Sun=7.
            initial: _initials[(day.date.weekday - 1) % 7],
            read: day.read,
            isToday: today != null &&
                day.date.year == today.year &&
                day.date.month == today.month &&
                day.date.day == today.day,
          ),
      ],
    );
  }
}

class _DayBubble extends StatelessWidget {
  const _DayBubble({
    required this.initial,
    required this.read,
    required this.isToday,
  });
  final String initial;
  final bool read;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: read ? AppColors.successJuice : AppColors.night800,
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? AppColors.indigo400 : AppColors.night700,
          width: isToday ? 2.5 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: read
          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
          : Text(
              initial,
              style: AppType.caption.copyWith(color: AppColors.inkMuted),
            ),
    );
  }
}
