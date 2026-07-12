import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// A full-bleed animated night sky: a vertical gradient from [AppColors.night900]
/// up through [AppColors.night800], ~[starCount] procedurally-placed stars that
/// twinkle on staggered phases, a hand-authored crescent moon, and a pair of
/// slow drifting cloud wisps.
///
/// The star field is **deterministic**: positions/sizes/phases are derived from
/// [seed] via a seeded [math.Random], so the same seed always paints the same
/// sky (stable across rebuilds and golden tests). All motion is driven by a
/// single [AnimationController] and the paint is wrapped in a [RepaintBoundary],
/// so animating the sky never repaints the widgets layered on top of it.
///
/// Reduced motion → a fully static (but still pretty) sky: stars sit at their
/// mid-brightness, the moon glows, wisps hold position, no controller ticks.
///
/// Typically used as the bottom layer of a [Stack] that fills the screen:
/// ```dart
/// Stack(children: [const Positioned.fill(child: NightSky()), content]);
/// ```
class NightSky extends StatefulWidget {
  const NightSky({
    super.key,
    this.starCount = 40,
    this.seed = 7,
    this.moonAlignment = const Alignment(0.62, -0.62),
    this.moonRadius = 34,
    this.showMoon = true,
    this.showWisps = true,
    this.child,
  });

  /// Number of stars to scatter. Clamped to a sane range internally.
  final int starCount;

  /// Seed for the deterministic star field.
  final int seed;

  /// Where the crescent moon sits (Alignment space, -1..1 on each axis).
  final Alignment moonAlignment;

  /// Radius of the moon disc in logical pixels.
  final double moonRadius;

  final bool showMoon;
  final bool showWisps;

  /// Optional content painted above the sky (kept out of the RepaintBoundary
  /// so its own repaints don't invalidate the sky and vice-versa).
  final Widget? child;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // One slow master loop; per-star phases fan out across it.
    duration: const Duration(seconds: 12),
  );

  late List<_Star> _stars = _buildStars();

  List<_Star> _buildStars() {
    final rng = math.Random(widget.seed);
    final count = widget.starCount.clamp(0, 240);
    return List<_Star>.generate(count, (_) {
      return _Star(
        // Normalised 0..1 position; the painter scales to its canvas.
        dx: rng.nextDouble(),
        dy: rng.nextDouble() * 0.92, // keep off the very bottom edge
        radius: 0.6 + rng.nextDouble() * 1.8,
        phase: rng.nextDouble(),
        // A few stars are "warm" (amber) for variety; most are cool white.
        warm: rng.nextDouble() < 0.18,
        twinkleSpeed: 0.6 + rng.nextDouble() * 0.9,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    // Only spin the controller when motion is allowed; started in didChange…
    // via the first build's reduced-motion read.
  }

  @override
  void didUpdateWidget(covariant NightSky oldWidget) {
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

    final painter = RepaintBoundary(
      child: CustomPaint(
        painter: _NightSkyPainter(
          stars: _stars,
          progress:
              reduce ? const AlwaysStoppedAnimation<double>(0.5) : _controller,
          reduce: reduce,
          showMoon: widget.showMoon,
          showWisps: widget.showWisps,
          moonAlignment: widget.moonAlignment,
          moonRadius: widget.moonRadius,
        ),
        isComplex: true,
        willChange: !reduce,
        child: const SizedBox.expand(),
      ),
    );

    if (widget.child == null) return painter;
    return Stack(
      fit: StackFit.expand,
      children: [painter, widget.child!],
    );
  }
}

class _Star {
  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
    required this.warm,
    required this.twinkleSpeed,
  });

  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final bool warm;
  final double twinkleSpeed;
}

class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter({
    required this.stars,
    required this.progress,
    required this.reduce,
    required this.showMoon,
    required this.showWisps,
    required this.moonAlignment,
    required this.moonRadius,
  }) : super(repaint: progress);

  final List<_Star> stars;
  final Animation<double> progress;
  final bool reduce;
  final bool showMoon;
  final bool showWisps;
  final Alignment moonAlignment;
  final double moonRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = progress.value; // 0..1 master phase

    // 1) Gradient sky.
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppColors.night900,
          AppColors.night800,
          AppColors.night700,
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    // 2) Drifting wisps (very soft, low opacity ellipses).
    if (showWisps) {
      _paintWisp(canvas, size, t, offset: 0.0, yFrac: 0.28, opacity: 0.05);
      _paintWisp(canvas, size, t, offset: 0.5, yFrac: 0.5, opacity: 0.035);
    }

    // 3) Stars.
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      // Staggered twinkle: a sine on the master phase shifted by the star phase.
      final wave = reduce
          ? 0.5
          : 0.5 +
              0.5 *
                  math.sin(
                    (t * s.twinkleSpeed + s.phase) * math.pi * 2,
                  );
      final opacity = 0.35 + 0.6 * wave; // never fully invisible
      final scale = 0.75 + 0.35 * wave;
      final center = Offset(s.dx * size.width, s.dy * size.height);
      final color = s.warm ? AppColors.amber500 : AppColors.ink;

      // Soft glow halo for larger stars.
      if (s.radius > 1.4) {
        starPaint
          ..color = color.withValues(alpha: 0.12 * wave)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(center, s.radius * scale * 2.4, starPaint);
        starPaint.maskFilter = null;
      }
      starPaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, s.radius * scale, starPaint);
    }

    // 4) Crescent moon (two-disc "boolean" look: full disc minus an offset disc).
    if (showMoon) {
      _paintMoon(canvas, size);
    }
  }

  void _paintWisp(
    Canvas canvas,
    Size size,
    double t, {
    required double offset,
    required double yFrac,
    required double opacity,
  }) {
    // Drift horizontally across the canvas, wrapping.
    final phase = (t + offset) % 1.0;
    final cx = (phase * 1.4 - 0.2) * size.width;
    final cy = yFrac * size.height;
    final w = size.width * 0.5;
    final h = size.height * 0.10;
    final paint = Paint()
      ..color = AppColors.indigo400.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      paint,
    );
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = moonAlignment.alongSize(size);
    final r = moonRadius;

    // Soft outer glow.
    canvas.drawCircle(
      center,
      r * 1.8,
      Paint()
        ..color = AppColors.amber500.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
    );

    // Full disc.
    final full = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    // Offset disc that "bites" the crescent out.
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.55, -r * 0.18),
          radius: r * 0.92,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, full, bite);

    final moonPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          const Color(0xFFFFF4D6),
          AppColors.amber500.withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(crescent, moonPaint);
  }

  @override
  bool shouldRepaint(covariant _NightSkyPainter old) =>
      old.stars != stars ||
      old.reduce != reduce ||
      old.showMoon != showMoon ||
      old.showWisps != showWisps ||
      old.moonAlignment != moonAlignment ||
      old.moonRadius != moonRadius;
}
