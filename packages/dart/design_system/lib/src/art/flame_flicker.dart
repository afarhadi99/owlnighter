import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// A layered, organically-flickering flame drawn from three nested hand-authored
/// SVG flame paths — outer [AppColors.flame500] orange, mid [AppColors.amber500],
/// and an inner cream core — over a soft radial glow.
///
/// [intensity] (0..1) scales the flame's height, glow, and flicker energy; wire
/// it to streak length (e.g. `(streakCount / 30).clamp(0, 1)`) so a long streak
/// burns bigger and brighter. Flicker is driven by summed sines at different
/// frequencies per layer (a cheap pseudo-noise) on a single ticker, producing
/// scale/skew wobble that never looks mechanically periodic.
///
/// Reduced motion → a static, fully-formed flame at the given intensity (no
/// ticking controller), still layered and glowing.
class FlameFlicker extends StatefulWidget {
  const FlameFlicker({
    super.key,
    this.intensity = 0.7,
    this.size = 96,
    this.semanticLabel,
  });

  /// 0..1 — drives height, glow radius, and flicker amplitude.
  final double intensity;

  final double size;

  /// Optional a11y label; defaults to describing the intensity.
  final String? semanticLabel;

  @override
  State<FlameFlicker> createState() => _FlameFlickerState();
}

class _FlameFlickerState extends State<FlameFlicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

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

    final intensity = widget.intensity.clamp(0.0, 1.0);
    return Semantics(
      label: widget.semanticLabel ??
          'Streak flame, intensity ${(intensity * 100).round()} percent',
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _FlamePainter(
              progress: reduce
                  ? const AlwaysStoppedAnimation<double>(0.0)
                  : _controller,
              intensity: intensity,
              reduce: reduce,
            ),
            size: Size.square(widget.size),
          ),
        ),
      ),
    );
  }
}

class _FlamePaths {
  // Authored in a 0..100 viewbox, flame pointing up. Three nested teardrops.
  static final Path outer = parseSvgPathData(
    'M50 8 '
    'C64 30 78 44 78 64 '
    'C78 84 66 96 50 96 '
    'C34 96 22 84 22 64 '
    'C22 44 36 30 50 8 Z',
  );

  static final Path mid = parseSvgPathData(
    'M50 26 '
    'C60 40 68 50 68 66 '
    'C68 82 60 90 50 90 '
    'C40 90 32 82 32 66 '
    'C32 50 40 40 50 26 Z',
  );

  static final Path inner = parseSvgPathData(
    'M50 46 '
    'C56 54 60 60 60 70 '
    'C60 82 55 88 50 88 '
    'C45 88 40 82 40 70 '
    'C40 60 44 54 50 46 Z',
  );
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({
    required this.progress,
    required this.intensity,
    required this.reduce,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double intensity;
  final bool reduce;

  /// Cheap layered pseudo-noise: sum of sines at incommensurate frequencies.
  double _noise(double t, double seed) {
    return (math.sin((t + seed) * math.pi * 2) * 0.6 +
            math.sin((t * 2.3 + seed * 1.7) * math.pi * 2) * 0.3 +
            math.sin((t * 5.1 + seed * 0.4) * math.pi * 2) * 0.1) /
        1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    final t = progress.value;
    final flickerAmp = reduce ? 0.0 : (0.04 + 0.10 * intensity);

    // Overall flame height grows with intensity (0.55..1.05).
    final heightScale = 0.55 + 0.5 * intensity;

    // Soft glow behind the flame.
    final glowR = size.width *
        (0.30 + 0.18 * intensity) *
        (1 + (reduce ? 0 : _noise(t, 0.2) * 0.06));
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.62),
      glowR,
      Paint()
        ..color = AppColors.flame500.withValues(alpha: 0.18 + 0.12 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR * 0.6),
    );

    canvas.save();
    canvas.scale(scale);

    // Anchor scaling/skew at the flame base (bottom-center of the 100-box).
    const base = Offset(50, 96);

    _drawLayer(
      canvas,
      _FlamePaths.outer,
      base,
      heightScale: heightScale,
      skew: flickerAmp * _noise(t, 0.0),
      squash: 1 + flickerAmp * _noise(t, 0.5),
      color: AppColors.flame500,
    );
    _drawLayer(
      canvas,
      _FlamePaths.mid,
      base,
      heightScale: heightScale,
      skew: flickerAmp * 1.4 * _noise(t, 0.33),
      squash: 1 + flickerAmp * 1.3 * _noise(t, 0.8),
      color: AppColors.amber500,
    );
    _drawLayer(
      canvas,
      _FlamePaths.inner,
      base,
      heightScale: heightScale,
      skew: flickerAmp * 1.9 * _noise(t, 0.66),
      squash: 1 + flickerAmp * 1.6 * _noise(t, 0.1),
      color: const Color(0xFFFFF3D6),
    );

    canvas.restore();
  }

  void _drawLayer(
    Canvas canvas,
    Path path,
    Offset base, {
    required double heightScale,
    required double skew,
    required double squash,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    // Skew horizontally (lean the tongue) and scale height for flicker/intensity.
    final m = Matrix4.identity()
      ..scaleByDouble(squash, heightScale, 1.0, 1.0)
      ..setEntry(0, 1, skew); // shear x by y
    canvas.transform(m.storage);
    canvas.translate(-base.dx, -base.dy);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) =>
      old.intensity != intensity || old.reduce != reduce;
}
