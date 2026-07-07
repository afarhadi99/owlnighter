import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'reduced_motion.dart';

/// A circular progress ring painted with [CustomPainter] and animated with an
/// [AnimationController]. Used for nightly-goal completion and streak fill.
///
/// The ring animates from its previous value to the new [progress] whenever the
/// value changes. Reduced motion snaps directly to the target.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 12,
    this.color = AppColors.amber500,
    this.trackColor = AppColors.night700,
    this.center,
  }) : assert(progress >= 0 && progress <= 1);

  /// 0.0 – 1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? center;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late Animation<double> _animation =
      AlwaysStoppedAnimation<double>(widget.progress);

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: oldWidget.progress,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasized),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingPainter(
              progress: reduce ? widget.progress : _animation.value,
              strokeWidth: widget.strokeWidth,
              color: widget.color,
              trackColor: widget.trackColor,
            ),
            child: Center(child: child),
          );
        },
        child: widget.center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Start at 12 o'clock and sweep clockwise.
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
