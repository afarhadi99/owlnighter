import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/adaptive_back_button.dart';
import '../../shared/widgets/async_value_view.dart';
import 'path_map_painter.dart';
import 'reading_path_controller.dart';

/// The scrollable reading-path map: a serpentine trail of unlockable nodes over
/// a calm night sky with parallax scenery. Tapping the available node opens
/// tonight's session.
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
      title: 'Your reading path',
      // Always offer a way back: pop when possible, else fall back to the
      // library. This screen can be reached via a stack-replacing `go(...)`
      // from the post-quiz flow, where there is nothing to pop.
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
  double _scrollOffset = 0;
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
    setState(() => _scrollOffset = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = serpentineCenters(
          count: plan.steps.length,
          width: width,
        );
        final completed = _completedCount(plan);
        final contentHeight =
            centers.isEmpty ? constraints.maxHeight : centers.last.dy + 160;

        return Stack(
          children: [
            // Parallax scenery scrolls (subtly) with the trail, above the fixed
            // NightSky and below the painted path.
            Positioned.fill(
              child: PathScenery(
                scrollOffset: _scrollOffset,
                showMoon: false,
              ),
            ),
            SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                width: width,
                height: contentHeight,
                child: Stack(
                  children: [
                    // Painted trail behind the nodes.
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PathMapPainter(
                          nodeCenters: centers,
                          completedCount: completed,
                        ),
                      ),
                    ),
                    // Node widgets on top.
                    for (var i = 0; i < plan.steps.length; i++)
                      _positionedNode(context, i, centers[i]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _positionedNode(BuildContext context, int i, Offset center) {
    final plan = widget.plan;
    final step = plan.steps[i];
    final state = plan.stateForIndex(step.stepIndex);
    final status = _mapStatus(state?.status);
    const size = 64.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PathNode(
            status: status,
            label: 'Night ${step.stepIndex + 1}: ${step.title}',
            diameter: size,
            onTap: status == PathNodeStatus.locked || state == null
                ? null
                : () {
                    ref.read(sfxServiceProvider).play(SoundEffect.tap);
                    context.push(Routes.step(plan.planId, state.stepId));
                  },
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: 120,
            child: Text(
              step.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  PathNodeStatus _mapStatus(StepStatus? s) => switch (s) {
        StepStatus.completed => PathNodeStatus.completed,
        StepStatus.available => PathNodeStatus.available,
        _ => PathNodeStatus.locked,
      };
}
