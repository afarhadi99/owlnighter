import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// Controls a [ConfettiBurst], letting a parent fire the celebration
/// imperatively via [play]. Attach it to a [ConfettiBurst] and call
/// `controller.play()` at the payoff moment (e.g. quiz passed).
class ConfettiController extends ChangeNotifier {
  int _generation = 0;
  int get generation => _generation;

  /// Fire (or re-fire) the burst. Each call advances a generation counter the
  /// widget listens to, restarting its one-shot animation.
  void play() {
    _generation++;
    notifyListeners();
  }
}

/// The little SVG shapes a confetti particle can take.
enum _Confetto { star, book, moon, circle }

/// A one-shot particle celebration: 60–100 tiny hand-authored SVG shapes
/// (star, book, crescent moon, circle) launched with randomized
/// velocity/gravity/spin and faded out over ~[duration] on a single ticker.
///
/// Fire it either declaratively (`autoPlay: true` plays once on first build) or
/// imperatively via a [ConfettiController.play]. The animation auto-stops when
/// finished (the ticker is idle between bursts), and everything disposes with
/// the widget.
///
/// Reduced motion → no flying particles; instead a gentle cluster of static
/// sparkles fades in and out once, so the moment is still marked without
/// vestibular-triggering movement.
///
/// Place it in a [Stack] above the content you want to celebrate over
/// (typically `Positioned.fill` with `IgnorePointer`, which this widget already
/// applies to itself).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.controller,
    this.autoPlay = false,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 1800),
    this.seed = 42,
    this.colors = const [
      AppColors.indigo400,
      AppColors.indigo500,
      AppColors.amber500,
      AppColors.flame500,
      AppColors.success500,
    ],
  });

  /// Imperative trigger. If null, use [autoPlay].
  final ConfettiController? controller;

  /// Play once automatically when first inserted.
  final bool autoPlay;

  /// Number of particles (clamped 10..160).
  final int particleCount;

  final Duration duration;
  final int seed;
  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  List<_Particle> _particles = const [];
  int _lastGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerPlay);
    if (widget.autoPlay) {
      // Fire after first frame so we have a size + Overlay context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fire();
      });
    }
  }

  void _onControllerPlay() {
    final gen = widget.controller!.generation;
    if (gen != _lastGeneration) {
      _lastGeneration = gen;
      _fire();
    }
  }

  void _fire() {
    _particles = _buildParticles();
    _controller
      ..reset()
      ..forward();
    setState(() {});
  }

  List<_Particle> _buildParticles() {
    final rng = math.Random(widget.seed + _lastGeneration);
    final count = widget.particleCount.clamp(10, 160);
    return List<_Particle>.generate(count, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.6 + rng.nextDouble() * 0.9;
      return _Particle(
        // Launch origin spread across the horizontal center band.
        originX: 0.5 + (rng.nextDouble() - 0.5) * 0.3,
        originY: 0.55,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 6 + rng.nextDouble() * 8,
        spin: (rng.nextDouble() - 0.5) * 12,
        rotation: rng.nextDouble() * math.pi * 2,
        color: widget.colors[rng.nextInt(widget.colors.length)],
        shape: _Confetto.values[rng.nextInt(_Confetto.values.length)],
        delay: rng.nextDouble() * 0.1,
      );
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerPlay);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(
            progress: _controller,
            particles: _particles,
            reduce: reduce,
            colors: widget.colors,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.originX,
    required this.originY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.rotation,
    required this.color,
    required this.shape,
    required this.delay,
  });

  final double originX; // 0..1 of width
  final double originY; // 0..1 of height
  final double vx; // normalized launch velocity
  final double vy;
  final double size;
  final double spin; // radians/sec-ish
  final double rotation;
  final Color color;
  final _Confetto shape;
  final double delay; // 0..1 fraction of duration
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.reduce,
    required this.colors,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Particle> particles;
  final bool reduce;
  final List<Color> colors;

  // Shapes authored in a unit-ish box centered on origin, scaled per particle.
  static final Path _star = parseSvgPathData(
    'M0 -1 L0.31 -0.31 L1 -0.31 L0.44 0.16 L0.62 0.9 '
    'L0 0.45 L-0.62 0.9 L-0.44 0.16 L-1 -0.31 L-0.31 -0.31 Z',
  );
  static final Path _book = parseSvgPathData(
    'M-0.9 -0.6 L-0.05 -0.4 L-0.05 0.7 L-0.9 0.5 Z '
    'M0.9 -0.6 L0.05 -0.4 L0.05 0.7 L0.9 0.5 Z',
  );
  static final Path _moon = () {
    final full = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0.5, -0.15), radius: 0.9));
    return Path.combine(PathOperation.difference, full, bite);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (reduce) {
      _paintStaticSparkle(canvas, size);
      return;
    }
    if (particles.isEmpty) return;
    final t = progress.value;
    if (t == 0) return; // not fired yet

    // Launch distance scale relative to the smaller dimension.
    final reach = size.shortestSide * 0.9;

    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Physics: linear launch + gravity, then fade in the last third.
      final gravity = 0.9 * local * local;
      final dx = p.vx * local * reach;
      final dy = (p.vy * local + gravity) * reach;
      final pos = Offset(
        p.originX * size.width + dx,
        p.originY * size.height + dy,
      );
      final opacity = local < 0.7 ? 1.0 : (1 - (local - 0.7) / 0.3);
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation + p.spin * local);
      canvas.scale(p.size);
      canvas.drawPath(
        _pathFor(p.shape),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  Path _pathFor(_Confetto shape) => switch (shape) {
        _Confetto.star => _star,
        _Confetto.book => _book,
        _Confetto.moon => _moon,
        _Confetto.circle => _circleUnit,
      };

  static final Path _circleUnit = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.9));

  /// Reduced-motion fallback: a still cluster of sparkles that fades in/out once.
  void _paintStaticSparkle(Canvas canvas, Size size) {
    final t = progress.value;
    // Bell-shaped opacity over the run.
    final opacity = t == 0 ? 0.0 : math.sin(t * math.pi);
    if (opacity <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.5);
    final rng = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = 20 + rng.nextDouble() * (size.shortestSide * 0.28);
      final pos = center + Offset(math.cos(a) * r, math.sin(a) * r);
      final sizePx = 6 + rng.nextDouble() * 8;
      final color = colors[i % colors.length];
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(sizePx);
      canvas.drawPath(
        _star,
        Paint()..color = color.withValues(alpha: opacity * 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.particles != particles || old.reduce != reduce;
}
