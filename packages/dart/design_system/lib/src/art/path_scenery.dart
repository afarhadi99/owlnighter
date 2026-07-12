import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// A decorative, non-interactive scenery layer for the reading path map. It
/// paints parallax clusters of stars and a distant crescent moon that sit
/// *behind* the serpentine path painter without ever stealing touches (the
/// whole widget is wrapped in [IgnorePointer]).
///
/// [scrollOffset] lets the caller couple the scenery to the path's scroll
/// position: near clusters drift faster than far ones ([parallax] controls the
/// spread), giving depth as the user scrolls the map. When animated, far stars
/// twinkle gently on a single shared controller.
///
/// Reduced motion → static field (no twinkle), parallax still tracks
/// [scrollOffset] because that is user-driven, not autonomous motion.
///
/// Usage — as the bottom of the path-map [Stack]:
/// ```dart
/// Stack(children: [
///   Positioned.fill(child: PathScenery(scrollOffset: controller.offset)),
///   SerpentinePath(...),
/// ]);
/// ```
class PathScenery extends StatefulWidget {
  const PathScenery({
    super.key,
    this.scrollOffset = 0,
    this.parallax = 0.4,
    this.seed = 11,
    this.starCount = 60,
    this.showMoon = true,
  });

  /// Scroll position of the path map (logical px). Drives parallax drift.
  final double scrollOffset;

  /// 0..1 — how much depth separation between near and far layers.
  final double parallax;

  final int seed;
  final int starCount;
  final bool showMoon;

  @override
  State<PathScenery> createState() => _PathSceneryState();
}

class _PathSceneryState extends State<PathScenery>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  late List<_SceneStar> _stars = _buildStars();

  List<_SceneStar> _buildStars() {
    final rng = math.Random(widget.seed);
    final count = widget.starCount.clamp(0, 300);
    return List<_SceneStar>.generate(count, (_) {
      // depth 0 = far (slow, dim, small), 1 = near (fast, bright, big).
      final depth = rng.nextDouble();
      return _SceneStar(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        depth: depth,
        radius: 0.5 + depth * 1.8,
        phase: rng.nextDouble(),
        warm: rng.nextDouble() < 0.14,
      );
    });
  }

  @override
  void didUpdateWidget(covariant PathScenery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.starCount != widget.starCount) {
      _stars = _buildStars();
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
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SceneryPainter(
            stars: _stars,
            twinkle: reduce
                ? const AlwaysStoppedAnimation<double>(0.5)
                : _controller,
            reduce: reduce,
            scrollOffset: widget.scrollOffset,
            parallax: widget.parallax.clamp(0.0, 1.0),
            showMoon: widget.showMoon,
          ),
          isComplex: true,
          willChange: !reduce,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SceneStar {
  const _SceneStar({
    required this.dx,
    required this.dy,
    required this.depth,
    required this.radius,
    required this.phase,
    required this.warm,
  });

  final double dx;
  final double dy;
  final double depth;
  final double radius;
  final double phase;
  final bool warm;
}

class _SceneryPainter extends CustomPainter {
  _SceneryPainter({
    required this.stars,
    required this.twinkle,
    required this.reduce,
    required this.scrollOffset,
    required this.parallax,
    required this.showMoon,
  }) : super(repaint: twinkle);

  final List<_SceneStar> stars;
  final Animation<double> twinkle;
  final bool reduce;
  final double scrollOffset;
  final double parallax;
  final bool showMoon;

  @override
  void paint(Canvas canvas, Size size) {
    final t = twinkle.value;

    // Distant moon, parked in the upper area, drifts the least (far depth).
    if (showMoon) {
      final moonShift = -scrollOffset * parallax * 0.08;
      final center = Offset(size.width * 0.72, size.height * 0.16 + moonShift);
      final r = size.shortestSide * 0.09;
      canvas.drawCircle(
        center,
        r * 1.7,
        Paint()
          ..color = AppColors.amber500.withValues(alpha: 0.07)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
      final full = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      final bite = Path()
        ..addOval(
          Rect.fromCircle(
            center: center + Offset(r * 0.5, -r * 0.2),
            radius: r * 0.92,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, full, bite),
        Paint()..color = const Color(0xFFFFF0CC).withValues(alpha: 0.55),
      );
    }

    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      // Parallax: nearer stars (higher depth) shift more with scroll.
      final shift = -scrollOffset * parallax * (0.05 + s.depth * 0.35);
      var y = (s.dy * size.height + shift) % size.height;
      if (y < 0) y += size.height;
      final center = Offset(s.dx * size.width, y);

      final wave =
          reduce ? 0.5 : 0.5 + 0.5 * math.sin((t + s.phase) * math.pi * 2);
      final opacity = (0.2 + 0.5 * s.depth) * (0.6 + 0.4 * wave);
      final color = s.warm ? AppColors.amber500 : AppColors.ink;
      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, s.radius * (0.85 + 0.15 * wave), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter old) =>
      old.stars != stars ||
      old.reduce != reduce ||
      old.scrollOffset != scrollOffset ||
      old.parallax != parallax ||
      old.showMoon != showMoon;
}
