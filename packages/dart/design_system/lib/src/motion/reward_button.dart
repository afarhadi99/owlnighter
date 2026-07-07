import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'reduced_motion.dart';

/// "Juicy" button press feedback: a brief scale transform plus a medium haptic.
///
/// This is the canonical motion wrapper from the blueprint — standardize it
/// across the design system instead of sprinkling raw animation code. When the
/// OS requests reduced motion, we skip the scale + haptic and just fire [onTap].
class RewardButton extends StatefulWidget {
  const RewardButton({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<RewardButton> createState() => _RewardButtonState();
}

class _RewardButtonState extends State<RewardButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 90),
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.96).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    await HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = reduceMotionOf(context);
    return GestureDetector(
      onTap: reduceMotion ? widget.onTap : _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: reduceMotion ? 1 : _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
