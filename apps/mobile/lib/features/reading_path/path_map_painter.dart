import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/theme/theme_re_exports.dart';

/// Paints the winding "trail" connecting reading-path nodes. The nodes
/// themselves are real widgets (PathNode) positioned on top; this painter only
/// draws the connecting path so the map reads as a single journey.
///
/// Nodes are laid out in a serpentine down the scroll view. [nodeCenters] are
/// the widget-space centers computed by the layout; we stroke a smooth curve
/// through them.
class PathMapPainter extends CustomPainter {
  PathMapPainter({
    required this.nodeCenters,
    required this.completedCount,
  });

  final List<Offset> nodeCenters;

  /// How many leading nodes are completed — the trail up to there is drawn in
  /// the "done" color, the rest muted.
  final int completedCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCenters.length < 2) return;

    final donePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.success500.withValues(alpha: 0.9);
    final pendingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.night700;

    for (var i = 0; i < nodeCenters.length - 1; i++) {
      final a = nodeCenters[i];
      final b = nodeCenters[i + 1];
      // Control points bow the segment sideways for an organic trail.
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final bow = (i.isEven ? 1 : -1) * 28.0;
      final control = mid + Offset(bow, 0);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
      canvas.drawPath(path, i < completedCount - 1 ? donePaint : pendingPaint);
    }
  }

  @override
  bool shouldRepaint(PathMapPainter old) =>
      old.completedCount != completedCount ||
      !_sameOffsets(old.nodeCenters, nodeCenters);

  static bool _sameOffsets(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distanceSquared > 0.5) return false;
    }
    return true;
  }
}

/// Serpentine layout: computes node centers for [count] nodes given the
/// available [width], vertical [spacing], and horizontal [amplitude].
List<Offset> serpentineCenters({
  required int count,
  required double width,
  double topPadding = 80,
  double spacing = 120,
  double amplitude = 90,
}) {
  final centerX = width / 2;
  return List<Offset>.generate(count, (i) {
    final phase = math.sin(i * math.pi / 2);
    return Offset(centerX + phase * amplitude, topPadding + i * spacing);
  });
}
