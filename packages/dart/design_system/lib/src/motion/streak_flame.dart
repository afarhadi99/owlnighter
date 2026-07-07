import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../tokens.dart';
import 'reduced_motion.dart';

/// The streak flame mascot. This is a Rive state-machine hook: the flame asset
/// exposes inputs `active` (is the streak alive) and `count` (streak length, so
/// the artboard can grow the flame). Rive is the right tool here because the
/// flame is a *stateful* interactive animation, not a one-shot.
///
/// The asset is intentionally NOT bundled yet (design owns `streak_flame.riv`).
/// Until it ships, or when reduced motion is on, we render a static placeholder
/// so the app is fully functional without the binary asset.
class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.streakCount,
    this.size = 96,
    this.assetPath = 'assets/rive/streak_flame.riv',
    this.stateMachine = 'FlameStateMachine',
  });

  final int streakCount;
  final double size;
  final String assetPath;
  final String stateMachine;

  bool get isActive => streakCount > 0;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> {
  StateMachineController? _controller;
  SMIBool? _active;
  SMINumber? _count;
  bool _assetFailed = false;

  void _onRiveInit(Artboard artboard) {
    final controller =
        StateMachineController.fromArtboard(artboard, widget.stateMachine);
    if (controller == null) {
      setState(() => _assetFailed = true);
      return;
    }
    artboard.addController(controller);
    _controller = controller;
    _active = controller.findInput<bool>('active') as SMIBool?;
    _count = controller.findInput<double>('count') as SMINumber?;
    _syncInputs();
  }

  void _syncInputs() {
    _active?.value = widget.isActive;
    _count?.value = widget.streakCount.toDouble();
  }

  @override
  void didUpdateWidget(covariant StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakCount != widget.streakCount) _syncInputs();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    // Reduced motion or a missing asset → static placeholder.
    if (reduce || _assetFailed) {
      return _FlamePlaceholder(size: widget.size, active: widget.isActive);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RiveAnimation.asset(
        widget.assetPath,
        stateMachines: [widget.stateMachine],
        onInit: _onRiveInit,
        // If the asset can't load, fall back gracefully.
        antialiasing: true,
      ),
    );
  }
}

class _FlamePlaceholder extends StatelessWidget {
  const _FlamePlaceholder({required this.size, required this.active});
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.local_fire_department_rounded,
        size: size * 0.8,
        color: active ? AppColors.flame500 : AppColors.inkMuted,
        semanticLabel: active ? 'Streak active' : 'Streak inactive',
      ),
    );
  }
}
