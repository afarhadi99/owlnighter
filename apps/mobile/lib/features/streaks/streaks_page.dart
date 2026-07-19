import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/extras_api.dart';
import '../../shared/mood/owl_mood.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';

/// Hydrates the streak tab from `GET /v1/me/stats` on open. Auto-disposes so it
/// refetches each time the tab is shown (e.g. after finishing a night).
final myStatsProvider = FutureProvider.autoDispose<MyStats>((ref) async {
  return ref.watch(statsApiProvider).fetchStats();
});

/// The streak tab, rebuilt to the cozy-nocturnal prototype: a big breathing
/// flame with the live day count nestled in it, the owl mood banner, Longest /
/// Total-XP stat cards, a "This week" S–M–T–W row, a multi-week heat calendar
/// of nights read, and milestone chips with progress. Every value is drawn from
/// the real [MyStats] the tab already loads — nothing is fabricated.
class StreaksPage extends ConsumerWidget {
  const StreaksPage({super.key, this.now});

  /// Optional clock override for tests; defaults to the real wall clock at
  /// the point of use.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    return NightScaffold(
      title: 'Streak',
      starCount: 28,
      body: AsyncValueView<MyStats>(
        value: stats,
        onRetry: () => ref.invalidate(myStatsProvider),
        data: (s) => _StatsBody(stats: s, now: now),
      ),
    );
  }
}

class _StatsBody extends StatefulWidget {
  const _StatsBody({required this.stats, this.now});
  final MyStats stats;

  /// Optional clock override for tests; defaults to the real wall clock at
  /// the point of use (mirrors [OwlMascot]'s injectable `random`).
  final DateTime? now;

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody>
    with SingleTickerProviderStateMixin {
  /// The reveal clock: sections fade + rise in a gentle stagger, matching the
  /// completion page's language. Collapses to "shown" under reduced motion.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

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
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final intensity = (stats.currentStreak / 14.0).clamp(0.3, 1.0);
    final hasReadToday = stats.week.isNotEmpty && stats.week.last.read;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Keep the lamp lit" kicker, centered above the hero.
          Text(
            'KEEP THE LAMP LIT',
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(
              color: AppColors.lamp,
              letterSpacing: 2.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RiseIn(
            reveal: _reveal,
            start: 0,
            end: 0.4,
            child: _StreakHero(
              streak: stats.currentStreak,
              longest: stats.longestStreak,
              intensity: intensity,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _RiseIn(
            reveal: _reveal,
            start: 0.15,
            end: 0.5,
            child: _MoodBanner(
              hasReadToday: hasReadToday,
              now: widget.now ?? DateTime.now(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RiseIn(
            reveal: _reveal,
            start: 0.28,
            end: 0.62,
            child: Row(
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
          ),
          const SizedBox(height: AppSpacing.xl),
          _RiseIn(
            reveal: _reveal,
            start: 0.4,
            end: 0.72,
            child: const _SectionLabel('This week'),
          ),
          const SizedBox(height: AppSpacing.md),
          _RiseIn(
            reveal: _reveal,
            start: 0.44,
            end: 0.78,
            child: _CardWell(child: _WeekRow(week: stats.week)),
          ),
          const SizedBox(height: AppSpacing.xl),
          _RiseIn(
            reveal: _reveal,
            start: 0.54,
            end: 0.84,
            child: const _SectionLabel('Nights read · last 6 weeks'),
          ),
          const SizedBox(height: AppSpacing.md),
          _RiseIn(
            reveal: _reveal,
            start: 0.58,
            end: 0.9,
            child: _CardWell(
              child: _HeatCalendar(
                week: stats.week,
                currentStreak: stats.currentStreak,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _RiseIn(
            reveal: _reveal,
            start: 0.68,
            end: 0.94,
            child: const _SectionLabel('Milestones'),
          ),
          const SizedBox(height: AppSpacing.md),
          _RiseIn(
            reveal: _reveal,
            start: 0.72,
            end: 1.0,
            child: _Milestones(
              currentStreak: stats.currentStreak,
              reveal: _reveal,
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero: a big breathing flame with the live day count nestled low in it,
/// a serif "N-day streak" label, and a longest-streak-aware subtitle.
class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.streak,
    required this.longest,
    required this.intensity,
  });

  final int streak;
  final int longest;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final subtitle = streak >= longest && streak > 0
        ? 'Your longest lamp yet. Sleep well.'
        : streak == 0
            ? 'Light tonight’s lamp to start a new streak.'
            : 'Keep going — you’re ${longest - streak} from your best.';
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FlameFlicker(
                intensity: intensity,
                size: 150,
                semanticLabel: '$streak-day streak flame',
              ),
              // The day count nestled low in the flame, in a warm dark ink so it
              // reads against the lamp-gold body.
              Positioned(
                bottom: 26,
                child: Text(
                  '$streak',
                  style: AppType.display.copyWith(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5A3410),
                    shadows: const [
                      Shadow(color: Color(0x99FFF0C8), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$streak-day streak',
          style: AppType.title.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// A compact card pairing the mood-reflecting owl with a short nudge/praise
/// message, so the streak tab reflects whether tonight's reading is done yet.
class _MoodBanner extends StatelessWidget {
  const _MoodBanner({required this.hasReadToday, required this.now});

  final bool hasReadToday;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final mood = owlMoodFor(hasReadToday: hasReadToday, now: now);
    final message = switch (mood) {
      OwlState.cheer => 'Nicely done tonight! Keep the streak alive.',
      OwlState.idle => 'Plenty of time — tonight’s reading is waiting.',
      OwlState.worried => 'Getting late — don’t forget tonight’s reading.',
      OwlState.angry =>
        'You still haven’t read tonight! Your streak is on the line.',
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night700, AppColors.night800],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          OwlMascot(state: mood, size: 60),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lamp-gold-uppercase section header, matching the prototype's `.sect-label`.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // The visible label keeps its natural case (so 'This week' still matches
    // exactly), with tracked-out letterforms for the storybook section feel.
    return Text(
      text,
      style: AppType.headline.copyWith(fontSize: 15, letterSpacing: 0.4),
    );
  }
}

/// A plum "well" card that wraps the week row / heat calendar, matching the
/// prototype's inset `.card` with 16px padding.
class _CardWell extends StatelessWidget {
  const _CardWell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night700, AppColors.night800],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// A row of seven day-initial bubbles: filled green when read that day, today
/// gets a twilight ring.
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: read
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7CF0C2), AppColors.success500],
              )
            : null,
        color: read ? null : AppColors.night800,
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday
              ? AppColors.twilightHi
              : (read ? Colors.transparent : AppColors.line),
          width: isToday ? 2.5 : 1.5,
        ),
        boxShadow: read
            ? const [
                BoxShadow(color: Color(0x3352E0A6), blurRadius: 8),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: read
          ? const Icon(Icons.check_rounded, size: 20, color: Color(0xFF053D29))
          : Text(
              initial,
              style: AppType.caption.copyWith(
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// A 6-week (42-cell) heat calendar of nights read, ending today (bottom-right).
///
/// Honest to the data the tab actually has: a cell is lit only when we KNOW the
/// night was read — either it falls in the trailing 7-day [week] window and is
/// marked read, or it lies within the current unbroken streak (which, by
/// definition, is consecutive read nights back from today). Older, unknown
/// nights stay dark. Cells in the live streak burn brightest.
class _HeatCalendar extends StatelessWidget {
  const _HeatCalendar({required this.week, required this.currentStreak});

  final List<StatsDay> week;
  final int currentStreak;

  int _levelFor(int daysAgo) {
    // Within the live streak → strongest lamp.
    if (daysAgo < currentStreak) return 4;
    // Otherwise, if we have a trailing-week record, honour it.
    if (daysAgo < 7 && week.length >= 7) {
      final day = week[week.length - 1 - daysAgo];
      if (day.read) return 3;
    }
    return 0;
  }

  Color _cellColor(int level) => switch (level) {
        1 => const Color(0x38FFCE7A),
        2 => const Color(0x73FFCE7A),
        3 => const Color(0xB8FFB347),
        4 => AppColors.lamp,
        _ => AppColors.night700,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < 42; i++)
              _HeatCell(
                color: _cellColor(_levelFor(41 - i)),
                glow: _levelFor(41 - i) == 4,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'less',
              style: AppType.caption.copyWith(
                color: AppColors.faint,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(width: 6),
            for (final l in const [0, 1, 2, 3, 4]) ...[
              _LegendSwatch(color: _cellColor(l)),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 2),
            Text(
              'more',
              style: AppType.caption.copyWith(
                color: AppColors.faint,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.color, required this.glow});
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line, width: 0.5),
        boxShadow: glow
            ? const [BoxShadow(color: Color(0x66FFB347), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
    );
  }
}

/// Milestone chips: a medal that lights lamp-gold when hit, the target, and a
/// progress bar (eased in) toward the next lamp for those not yet reached.
class _Milestones extends StatelessWidget {
  const _Milestones({required this.currentStreak, required this.reveal});

  final int currentStreak;
  final Animation<double> reveal;

  static const _defs = <({int nights, String title, String emoji})>[
    (nights: 7, title: 'One week lit', emoji: '🌙'),
    (nights: 14, title: 'Fortnight flame', emoji: '🔥'),
    (nights: 30, title: 'A month of nights', emoji: '⭐'),
    (nights: 100, title: 'Century of lamps', emoji: '👑'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night700, AppColors.night800],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _defs.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            _MilestoneRow(
              def: _defs[i],
              currentStreak: currentStreak,
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.def, required this.currentStreak});

  final ({int nights, String title, String emoji}) def;
  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final hit = currentStreak >= def.nights;
    final progress = (currentStreak / def.nights).clamp(0.0, 1.0);
    final reduce = reduceMotionOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Medal(emoji: def.emoji, hit: hit),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${def.title} · ${def.nights} nights',
                  style: AppType.label.copyWith(
                    color: hit ? AppColors.lamp : AppColors.moon,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hit
                      ? 'Earned — the flame remembers.'
                      : '$currentStreak / ${def.nights} nights',
                  style: AppType.caption.copyWith(color: AppColors.faint),
                ),
                if (!hit) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      height: 6,
                      color: AppColors.night600,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration:
                              reduce ? Duration.zero : AppMotion.slow,
                          curve: AppMotion.standard,
                          builder: (context, value, _) =>
                              FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.lampGlow,
                                    AppColors.lamp,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.emoji, required this.hit});
  final String emoji;
  final bool hit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hit
            ? const RadialGradient(
                center: Alignment(0, -0.3),
                colors: [Color(0xFFFFE6AE), AppColors.lamp, AppColors.lampGlow],
                stops: [0, 0.55, 1],
              )
            : null,
        color: hit ? null : AppColors.night600,
        border: Border.all(
          color: hit ? Colors.transparent : AppColors.line,
        ),
        boxShadow: hit
            ? const [BoxShadow(color: Color(0x66FFB347), blurRadius: 12)]
            : null,
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: hit ? 1 : 0.5,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Fades + rises its [child] into place across a [start]..[end] slice of the
/// [reveal] clock, producing the staggered reveal. Reduced motion shows it
/// immediately. Mirrors the completion page's `_RiseIn`.
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
