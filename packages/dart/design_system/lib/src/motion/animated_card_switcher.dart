import 'package:flutter/material.dart';

import '../tokens.dart';
import 'reduced_motion.dart';

/// Swaps between quiz-state cards (question → feedback → next question) with a
/// combined slide + fade. Wraps [AnimatedSwitcher] so callers just change the
/// child (each keyed distinctly) and get the transition for free.
///
/// Reduced motion degrades to a plain cross-fade with no slide.
class AnimatedCardSwitcher extends StatelessWidget {
  const AnimatedCardSwitcher({
    super.key,
    required this.child,
    this.forward = true,
  });

  final Widget child;

  /// Direction of travel: incoming card slides in from the right when true,
  /// from the left when false (e.g. going back).
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? AppMotion.fast : AppMotion.base,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (widget, animation) {
        final fade = FadeTransition(opacity: animation, child: widget);
        if (reduce) return fade;
        final dx = forward ? 0.12 : -0.12;
        final slide = Tween<Offset>(
          begin: Offset(dx, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: slide, child: fade);
      },
      // Ensure outgoing/incoming don't stack awkwardly during the swap.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: child,
    );
  }
}
