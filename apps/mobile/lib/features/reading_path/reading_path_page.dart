import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/api/extras_api.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/adaptive_back_button.dart';
import '../../shared/widgets/async_value_view.dart';
import '../library/library_controller.dart';
import 'path_map_painter.dart';
import 'reading_path_controller.dart';

/// Aggregate streak / XP for the path's top status header. Auto-disposes so it
/// refetches whenever the path is (re)opened — e.g. after finishing a night.
/// Degrades gracefully: the header shows a placeholder if this is unavailable.
final _pathStatsProvider = FutureProvider.autoDispose<MyStats>((ref) async {
  return ref.watch(statsApiProvider).fetchStats();
});

/// The reading-path map: a gently winding vertical trail of nights over a calm
/// plum night sky. Completed nights glow like kept lamps, tonight's node pulses
/// in twilight-violet with the owl beside it, and a "Tonight's reading" CTA
/// waits at the foot of the trail.
class ReadingPathPage extends ConsumerWidget {
  const ReadingPathPage({
    super.key,
    required this.planId,
    this.justCompleted = false,
  });
  final String planId;

  /// True when we arrived here straight from finishing a night — the path
  /// plays the unlock cue as the newly-available node appears.
  final bool justCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(readingPathControllerProvider(planId));
    return NightScaffold(
      // The hero status + book head inside the body carry the identity, so the
      // app bar is just a transparent back affordance.
      leading: const AdaptiveBackButton(fallbackLocation: Routes.library),
      body: AsyncValueView<ReadingPlan>(
        value: planAsync,
        onRetry: () => ref.invalidate(readingPathControllerProvider(planId)),
        data: (plan) => _PathMap(plan: plan, justCompleted: justCompleted),
      ),
    );
  }
}

class _PathMap extends ConsumerStatefulWidget {
  const _PathMap({required this.plan, this.justCompleted = false});
  final ReadingPlan plan;
  final bool justCompleted;

  @override
  ConsumerState<_PathMap> createState() => _PathMapState();
}

class _PathMapState extends ConsumerState<_PathMap> {
  final ScrollController _scroll = ScrollController();
  // Fed by [_onScroll] and consumed only by the [ValueListenableBuilder]
  // wrapping [PathScenery] below — scrolling therefore repaints just the
  // parallax background instead of rebuilding the whole node graph via
  // setState (which used to run on every scroll frame).
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  int? _lastCompleted;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _lastCompleted = _completedCount(widget.plan);
    // Arrived fresh from a completed night: the plan already shows the new
    // state, so play the unlock cue once after the first frame.
    if (widget.justCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(sfxServiceProvider).play(SoundEffect.unlock);
      });
    }
  }

  @override
  void didUpdateWidget(_PathMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the plan reloads with more completed steps, a new node has unlocked
    // — mark the moment with the unlock cue.
    final completed = _completedCount(widget.plan);
    if (_lastCompleted != null && completed > _lastCompleted!) {
      ref.read(sfxServiceProvider).play(SoundEffect.unlock);
    }
    _lastCompleted = completed;
  }

  int _completedCount(ReadingPlan plan) =>
      plan.stepStates.where((s) => s.status == StepStatus.completed).length;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // No setState: only the scenery's ValueListenableBuilder listens to this,
    // so a scroll frame repaints the parallax background, not the whole
    // _PathMapState.build() (serpentine layout + every trail node).
    _scrollOffset.value = _scroll.offset;
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  /// The book's display title, sourced from the (offline-first) library so the
  /// header can name the book the plan belongs to. Falls back gracefully.
  String _bookTitle() {
    final lib = ref.watch(libraryProvider);
    final match = lib.maybeWhen(
      data: (books) {
        for (final b in books) {
          if (b.bookId == widget.plan.bookId) return b;
        }
        return null;
      },
      orElse: () => null,
    );
    return match?.displayTitle ?? 'Tonight’s book';
  }

  /// Tonight's step (the first available), paired with its state, or null when
  /// the whole path is complete.
  ({PlanStep step, PlanStepState state})? _tonight() {
    final state = widget.plan.nextAvailable;
    if (state == null) return null;
    for (final s in widget.plan.steps) {
      if (s.stepIndex == state.stepIndex) return (step: s, state: state);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final total = plan.steps.length;
    final completed = _completedCount(plan);
    final nightsLeft = (total - completed).clamp(0, total);
    final currentNight = (completed + 1).clamp(1, total == 0 ? 1 : total);
    final tonight = _tonight();
    final statsAsync = ref.watch(_pathStatsProvider);

    return Column(
      children: [
        _StatusHeader(statsAsync: statsAsync, nightsLeft: nightsLeft),
        _BookHead(
          title: _bookTitle(),
          currentNight: currentNight,
          total: total,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final centers = serpentineCenters(count: total, width: width);
              final contentHeight = centers.isEmpty
                  ? constraints.maxHeight
                  : centers.last.dy + 210;

              return Stack(
                children: [
                  // Parallax scenery behind the trail (moon off — the header
                  // already sets the tone). Scoped to its own
                  // ValueListenableBuilder so scroll updates only rebuild this
                  // one widget, not the whole node graph below.
                  Positioned.fill(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollOffset,
                      builder: (context, offset, _) => PathScenery(
                        scrollOffset: offset,
                        showMoon: false,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      width: width,
                      height: contentHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PathMapPainter(
                                nodeCenters: centers,
                                completedCount: completed,
                              ),
                            ),
                          ),
                          for (var i = 0; i < plan.steps.length; i++)
                            _positionedNode(context, i, centers[i]),
                          ..._owlCompanion(centers, width),
                        ],
                      ),
                    ),
                  ),
                  // The fixed "Tonight's reading" CTA at the foot of the trail.
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _TonightCta(
                      tonight: tonight,
                      onBegin: tonight == null
                          ? null
                          : () {
                              ref
                                  .read(sfxServiceProvider)
                                  .play(SoundEffect.tap);
                              context.push(
                                Routes.step(plan.planId, tonight.state.stepId),
                              );
                            },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// The owl companion, floated beside tonight's node with a soft whisper.
  List<Widget> _owlCompanion(List<Offset> centers, double width) {
    final plan = widget.plan;
    for (var i = 0; i < plan.steps.length; i++) {
      final state = plan.stateForIndex(plan.steps[i].stepIndex);
      if (state?.status == StepStatus.available) {
        final c = centers[i];
        // Sit on whichever side of the node has more room, pushed far enough
        // out that the whisper bubble clears the node's centered caption.
        const owlW = 88.0;
        final onRight = c.dx > width / 2;
        final left = onRight
            ? (c.dx - 145).clamp(6.0, width - owlW)
            : (c.dx + 92).clamp(6.0, width - owlW);
        return [
          Positioned(
            left: left,
            top: c.dy - 34,
            child: const _OwlWhisper(),
          ),
        ];
      }
    }
    return const [];
  }

  Widget _positionedNode(BuildContext context, int i, Offset center) {
    final plan = widget.plan;
    final step = plan.steps[i];
    final state = plan.stateForIndex(step.stepIndex);
    final status = state?.status ?? StepStatus.locked;
    const nodeWidth = 118.0;
    const disc = 64.0;
    return Positioned(
      left: center.dx - nodeWidth / 2,
      top: center.dy - disc / 2,
      width: nodeWidth,
      child: _TrailNode(
        status: status,
        night: step.stepIndex + 1,
        title: step.title,
        onTap: (status == StepStatus.locked || state == null)
            ? null
            : () {
                ref.read(sfxServiceProvider).play(SoundEffect.tap);
                context.push(Routes.step(plan.planId, state.stepId));
              },
      ),
    );
  }
}

/// The compact top status header: a breathing streak flame with the day count,
/// XP, and how many nights remain on this path.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.statsAsync, required this.nightsLeft});

  final AsyncValue<MyStats> statsAsync;
  final int nightsLeft;

  @override
  Widget build(BuildContext context) {
    final streak = statsAsync.valueOrNull?.currentStreak;
    final xp = statsAsync.valueOrNull?.totalXp;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night600, AppColors.night700],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatPill(
              leading: FlameFlicker(
                intensity: streak == null
                    ? 0.3
                    : (0.3 + (streak / 30).clamp(0.0, 1.0) * 0.7),
                size: 30,
                semanticLabel: 'Streak',
              ),
              value: streak?.toString() ?? '—',
              label: 'day streak',
              valueColor: AppColors.lamp,
            ),
          ),
          const _PillDivider(),
          Expanded(
            child: _StatPill(
              value: xp == null ? '—' : _compact(xp),
              label: 'XP',
              valueColor: AppColors.twilightHi,
            ),
          ),
          const _PillDivider(),
          Expanded(
            child: _StatPill(
              leading: const Icon(
                Icons.nightlight_round,
                size: 18,
                color: AppColors.lamp,
              ),
              value: '$nightsLeft',
              label: 'nights left',
              valueColor: AppColors.moon,
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n < 1000) return '$n';
    final k = n / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.line);
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    required this.valueColor,
    this.leading,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.moon,
                letterSpacing: 0.4,
                height: 1.05,
              ).copyWith(color: valueColor),
            ),
            Text(
              label.toUpperCase(),
              style: AppType.caption.copyWith(
                color: AppColors.faint,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Now reading" kicker + serif book title + a where-you-are subtitle.
class _BookHead extends StatelessWidget {
  const _BookHead({
    required this.title,
    required this.currentNight,
    required this.total,
  });

  final String title;
  final int currentNight;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOW READING',
            style: AppType.caption.copyWith(
              color: AppColors.lamp,
              letterSpacing: 2.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.title,
          ),
          const SizedBox(height: 2),
          Text(
            total == 0
                ? 'Your reading path'
                : 'Night $currentNight of $total · keep the lamp lit.',
            style: AppType.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A single night on the trail. Completed nights glow lamp-gold, tonight's node
/// pulses in twilight-violet with a TONIGHT tag, and future nights are dim and
/// locked. Only the pulse of the "tonight" node ticks a controller, and it
/// collapses under reduced motion.
class _TrailNode extends StatefulWidget {
  const _TrailNode({
    required this.status,
    required this.night,
    required this.title,
    this.onTap,
  });

  final StepStatus status;
  final int night;
  final String title;
  final VoidCallback? onTap;

  @override
  State<_TrailNode> createState() => _TrailNodeState();
}

class _TrailNodeState extends State<_TrailNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.breathe,
  );
  bool _pressed = false;

  bool get _isTonight => widget.status == StepStatus.available;
  bool get _isDone => widget.status == StepStatus.completed;
  bool get _tappable => widget.onTap != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _TrailNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _sync();
  }

  void _sync() {
    final animate = _isTonight && !reduceMotionOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    const disc = 64.0;

    final decoration = switch (widget.status) {
      StepStatus.completed => const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [Color(0xFFFFE6AE), AppColors.lamp, AppColors.lampGlow],
            stops: [0, 0.45, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x80FFB347),
              blurRadius: 16,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
      StepStatus.available => const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 0.95,
            colors: [
              AppColors.twilightHi,
              AppColors.twilight,
              Color(0xFF6154C9),
            ],
            stops: [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x998E82F2),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, 6),
            ),
          ],
        ),
      StepStatus.locked => BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.night600, AppColors.night700],
          ),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
    };

    final icon = switch (widget.status) {
      StepStatus.completed => Icons.star_rounded,
      StepStatus.available => Icons.auto_stories_rounded,
      StepStatus.locked => Icons.lock_outline_rounded,
    };
    final iconColor = switch (widget.status) {
      StepStatus.completed => const Color(0xFF6B3D0F),
      StepStatus.available => Colors.white,
      StepStatus.locked => AppColors.faint,
    };

    final discWidget = AnimatedScale(
      scale: _pressed && _tappable && !reduce ? 0.92 : 1,
      duration: AppMotion.instant,
      child: Container(
        width: disc,
        height: disc,
        decoration: decoration,
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: disc * 0.42),
      ),
    );

    // Tonight's node gets a pulsing halo/ring behind the disc and a floating tag.
    Widget discStack = discWidget;
    if (_isTonight) {
      discStack = SizedBox(
        width: disc,
        height: disc,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = reduce ? 0.0 : _pulse.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Soft halo.
                IgnorePointer(
                  child: Container(
                    width: disc + 22 + t * 10,
                    height: disc + 22 + t * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.twilightHi.withValues(alpha: 0.45 * t),
                          AppColors.twilightHi.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Expanding ring.
                IgnorePointer(
                  child: Container(
                    width: disc + t * 26,
                    height: disc + t * 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.twilightHi.withValues(
                          alpha: 0.6 * (1 - t),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: discWidget,
        ),
      );
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The disc, with a floating TONIGHT tag hovering above when it's live.
        SizedBox(
          height: disc,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              discStack,
              if (_isTonight)
                const Positioned(top: -26, child: _TonightTag()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'NIGHT ${widget.night}',
          style: AppType.caption.copyWith(
            color: _isTonight ? AppColors.twilightHi : AppColors.faint,
            fontSize: 9.5,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(
            color: _isDone ? AppColors.inkMuted : AppColors.faint,
            height: 1.2,
          ),
        ),
      ],
    );

    return Semantics(
      button: _tappable,
      enabled: widget.status != StepStatus.locked,
      label: 'Night ${widget.night}: ${widget.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _tappable ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _tappable ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            _tappable ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: column,
      ),
    );
  }
}

/// The little lamp-gold "TONIGHT" pill that hovers over the live node.
class _TonightTag extends StatelessWidget {
  const _TonightTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lamp,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [
          BoxShadow(color: Color(0x66FFB347), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: const Text(
        'TONIGHT',
        style: TextStyle(
          color: Color(0xFF4A2C07),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// The floating owl beside tonight's node, with a soft whisper bubble.
class _OwlWhisper extends StatelessWidget {
  const _OwlWhisper();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OwlMascot(state: OwlState.idle, size: 56),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.night700.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'I kept the lamp warm. Ready when you are.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(
                color: AppColors.inkMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pinned "Tonight's reading" call-to-action at the foot of the trail.
class _TonightCta extends StatelessWidget {
  const _TonightCta({required this.tonight, required this.onBegin});

  final ({PlanStep step, PlanStepState state})? tonight;
  final VoidCallback? onBegin;

  @override
  Widget build(BuildContext context) {
    final done = tonight == null;
    final subtitle = done
        ? 'Every night on this path is lit.'
        : 'Night ${tonight!.step.stepIndex + 1} · ${tonight!.step.title}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.night700.withValues(alpha: 0.82),
            AppColors.night900.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          FlameFlicker(
            intensity: done ? 0.2 : 0.7,
            size: 30,
            semanticLabel: 'Tonight',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Path complete' : 'Tonight’s reading',
                  style: AppType.headline.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _BeginButton(onPressed: onBegin),
        ],
      ),
    );
  }
}

/// A compact lamp-gold "Begin" button for the CTA (chunky, tactile feel without
/// stretching full width).
class _BeginButton extends StatefulWidget {
  const _BeginButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_BeginButton> createState() => _BeginButtonState();
}

class _BeginButtonState extends State<_BeginButton> {
  bool _pressed = false;
  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final sink = _pressed && _enabled && !reduce;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: 'Begin tonight’s reading',
        child: Container(
          decoration: BoxDecoration(
            color: _enabled ? AppColors.amberEdge : AppColors.disabledFill,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: AnimatedPadding(
            duration: reduce ? Duration.zero : AppMotion.instant,
            padding: EdgeInsets.only(top: sink ? 4 : 0, bottom: sink ? 1 : 5),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                gradient: _enabled
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFDD99), AppColors.lamp],
                      )
                    : null,
                color: _enabled ? null : AppColors.disabledFill,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'BEGIN',
                style: AppType.label.copyWith(
                  color: _enabled
                      ? const Color(0xFF4A2C07)
                      : AppColors.disabledInk,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
