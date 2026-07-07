import 'package:flutter/material.dart';

import '../tokens.dart';
import 'reduced_motion.dart';

/// Visual state of a node on the reading path map.
enum PathNodeStatus { locked, available, completed }

/// A single unlockable node on the reading path. When a node transitions to
/// [PathNodeStatus.available] it pops in with an [AnimatedScale] "unlock" beat;
/// reduced motion collapses that to an instant appearance.
class PathNode extends StatelessWidget {
  const PathNode({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
    this.diameter = 64,
  });

  final PathNodeStatus status;
  final String label;
  final VoidCallback? onTap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final isLocked = status == PathNodeStatus.locked;

    final Color fill = switch (status) {
      PathNodeStatus.locked => AppColors.night700,
      PathNodeStatus.available => AppColors.indigo500,
      PathNodeStatus.completed => AppColors.success500,
    };

    final circle = AnimatedContainer(
      duration: reduce ? Duration.zero : AppMotion.base,
      curve: AppMotion.emphasized,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: fill.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Icon(
        switch (status) {
          PathNodeStatus.locked => Icons.lock_outline,
          PathNodeStatus.available => Icons.menu_book_rounded,
          PathNodeStatus.completed => Icons.check_rounded,
        },
        color: Colors.white,
        semanticLabel: label,
      ),
    );

    // Available nodes are the ones the user can act on → give them the unlock pop.
    final scaled = AnimatedScale(
      duration: reduce ? Duration.zero : AppMotion.slow,
      curve: reduce ? Curves.linear : AppMotion.bounce,
      scale: status == PathNodeStatus.available ? 1.08 : 1.0,
      child: circle,
    );

    return Semantics(
      button: onTap != null,
      enabled: !isLocked,
      label: label,
      child: GestureDetector(
        onTap: isLocked ? null : onTap,
        child: scaled,
      ),
    );
  }
}
