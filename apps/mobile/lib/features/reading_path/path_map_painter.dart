import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/theme/theme_re_exports.dart';

/// Paints the gently winding "trail" connecting reading-path nodes. The nodes
/// themselves are real widgets positioned on top; this painter only draws the
/// connecting path so the map reads as a single journey through the book.
///
/// The trail is a soft dotted line (echoing the prototype): the leading
/// [completedCount] portion glows warm lamplight — the nights you've "kept lit"
/// — and the remainder is a faint plum thread toward what's still to come.
class PathMapPainter extends CustomPainter {
  PathMapPainter({
    required this.nodeCenters,
    required this.completedCount,
  });

  final List<Offset> nodeCenters;

  /// How many leading nodes are completed — the trail up to there is drawn in
  /// warm lamplight, the rest in a faint plum thread.
  final int completedCount;

  // Dotted-line rhythm: a short dash + a wide gap reads as a row of dots when
  // stroked with a round cap.
  static const double _dash = 2.5;
  static const double _gap = 15;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCenters.length < 2) return;

    final path = _buildSmoothPath();
    final metrics = path.computeMetrics().toList();
    var total = 0.0;
    for (final m in metrics) {
      total += m.length;
    }
    if (total <= 0) return;

    final frac = (completedCount / nodeCenters.length).clamp(0.0, 1.0);
    final completedLen = total * frac;

    final lampPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.lamp;
    final lampGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.lampGlow.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final pendingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.line;

    var walked = 0.0;
    for (final m in metrics) {
      var d = 0.0;
      while (d < m.length) {
        final seg = m.extractPath(d, math.min(d + _dash, m.length));
        final atDist = walked + d;
        if (atDist <= completedLen) {
          canvas.drawPath(seg, lampGlow);
          canvas.drawPath(seg, lampPaint);
        } else {
          canvas.drawPath(seg, pendingPaint);
        }
        d += _dash + _gap;
      }
      walked += m.length;
    }
  }

  /// A smooth cubic thread through the node centers, with control points parked
  /// at each segment's mid-height so the curve eases vertically like the
  /// prototype's connector.
  Path _buildSmoothPath() {
    final p = Path()..moveTo(nodeCenters.first.dx, nodeCenters.first.dy);
    for (var i = 1; i < nodeCenters.length; i++) {
      final a = nodeCenters[i - 1];
      final b = nodeCenters[i];
      final midY = (a.dy + b.dy) / 2;
      p.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    return p;
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
/// available [width]. The winding is gentle (a soft sine sway) rather than a
/// hard zig-zag, so the trail feels like a calm bedtime path.
List<Offset> serpentineCenters({
  required int count,
  required double width,
  double topPadding = 72,
  double spacing = 118,
  double? amplitude,
}) {
  final centerX = width / 2;
  final amp = amplitude ?? width * 0.26;
  return List<Offset>.generate(count, (i) {
    // A gentle, non-integer phase avoids the sharp left/right/left snap of a
    // pi/2 phase and reads as a meandering trail.
    final phase = math.sin(i * 0.9);
    return Offset(centerX + phase * amp, topPadding + i * spacing);
  });
}
