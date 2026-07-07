import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/motion/motion.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';
import 'path_map_painter.dart';
import 'reading_path_controller.dart';

/// The scrollable reading-path map: a serpentine trail of unlockable nodes.
/// Tapping the available node opens tonight's session.
class ReadingPathPage extends ConsumerWidget {
  const ReadingPathPage({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(readingPathControllerProvider(planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Your reading path')),
      body: AsyncValueView<ReadingPlan>(
        value: planAsync,
        onRetry: () => ref.invalidate(readingPathControllerProvider(planId)),
        data: (plan) => _PathMap(plan: plan),
      ),
    );
  }
}

class _PathMap extends StatelessWidget {
  const _PathMap({required this.plan});
  final ReadingPlan plan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = serpentineCenters(
          count: plan.steps.length,
          width: width,
        );
        final completed = plan.stepStates
            .where((s) => s.status == StepStatus.completed)
            .length;
        final contentHeight = centers.isEmpty
            ? constraints.maxHeight
            : centers.last.dy + 160;

        return SingleChildScrollView(
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
        );
      },
    );
  }

  Widget _positionedNode(BuildContext context, int i, Offset center) {
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
                : () => context.push(Routes.step(plan.planId, state.stepId)),
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
