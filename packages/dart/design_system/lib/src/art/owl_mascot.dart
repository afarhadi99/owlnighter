import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// Behavioural states for [OwlMascot].
enum OwlState {
  /// Gentle breathing bob with a periodic double-blink.
  idle,

  /// Wing flap + upward bounce + bright, sparkling eyes (celebration).
  cheer,

  /// Half-closed eyes, slow bob, a floating "z" — bedtime mood.
  sleepy,
}

/// A charming owl mascot assembled from hand-authored SVG path layers (body,
/// belly, wings, brow tufts, eyes, pupils, beak, feet) and animated with a
/// single [CustomPainter]. All paths are authored in a 200x200 viewbox and
/// scaled to [size].
///
/// The owl reacts to [state]:
/// * [OwlState.idle] — breathes (subtle vertical bob + belly scale) and blinks
///   in a natural double-blink cadence.
/// * [OwlState.cheer] — flaps its wings, bounces, pupils turn to sparkles.
/// * [OwlState.sleepy] — eyes droop to half, the bob slows, and a "z" drifts up.
///
/// Reduced motion → a static owl posed for the current state (open eyes for
/// idle/cheer, drooped eyes for sleepy) with no ticking controller. Colours are
/// pulled from [AppColors]; nothing is hard-coded.
class OwlMascot extends StatefulWidget {
  const OwlMascot({
    super.key,
    this.state = OwlState.idle,
    this.size = 160,
    this.semanticLabel = 'Owl mascot',
  });

  final OwlState state;
  final double size;
  final String semanticLabel;

  @override
  State<OwlMascot> createState() => _OwlMascotState();
}

class _OwlMascotState extends State<OwlMascot> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  // Eased 0..1..0 value driving state transitions (eye droop, wing rest angle).
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant OwlMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _transition
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transition.dispose();
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

    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, _transition]),
            builder: (context, _) {
              return CustomPaint(
                painter: _OwlPainter(
                  state: widget.state,
                  t: reduce ? 0 : _controller.value,
                  transition: _transition.value,
                  reduce: reduce,
                ),
                size: Size.square(widget.size),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Parsed once; path strings are authored in a 0..200 coordinate space.
class _OwlPaths {
  static final Path body = parseSvgPathData(
    // Rounded egg-shaped body.
    'M100 34 '
    'C60 34 40 66 40 108 '
    'C40 158 66 184 100 184 '
    'C134 184 160 158 160 108 '
    'C160 66 140 34 100 34 Z',
  );

  static final Path belly = parseSvgPathData(
    'M100 78 '
    'C78 78 66 98 66 124 '
    'C66 154 82 172 100 172 '
    'C118 172 134 154 134 124 '
    'C134 98 122 78 100 78 Z',
  );

  // Left wing (owl's own left, screen right). Mirrored for the right wing.
  static final Path wingRight = parseSvgPathData(
    'M150 96 '
    'C166 104 168 138 156 160 '
    'C150 150 146 120 142 104 Z',
  );

  static final Path wingLeft = parseSvgPathData(
    'M50 96 '
    'C34 104 32 138 44 160 '
    'C50 150 54 120 58 104 Z',
  );

  static final Path browTufts = parseSvgPathData(
    // Two little ear/brow tufts on top of the head.
    'M74 40 C70 22 82 20 86 38 Z '
    'M126 40 C130 22 118 20 114 38 Z',
  );

  static final Path beak = parseSvgPathData(
    'M100 96 L90 108 L110 108 Z',
  );

  static final Path feet = parseSvgPathData(
    'M84 182 l-8 8 m8 -8 l0 10 m0 -10 l8 8 '
    'M116 182 l-8 8 m8 -8 l0 10 m0 -10 l8 8',
  );
}

class _OwlPainter extends CustomPainter {
  _OwlPainter({
    required this.state,
    required this.t,
    required this.transition,
    required this.reduce,
  });

  final OwlState state;
  final double t; // 0..1 master loop
  final double transition; // 0..1 state-transition ease
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale);

    final loop = t * math.pi * 2;

    // --- Per-state motion parameters -------------------------------------
    final double bobPeriod = switch (state) {
      OwlState.idle => 1.0,
      OwlState.cheer => 2.2,
      OwlState.sleepy => 0.5,
    };
    final double bobAmp = switch (state) {
      OwlState.idle => 3.0,
      OwlState.cheer => 9.0,
      OwlState.sleepy => 2.0,
    };
    final bob = reduce ? 0.0 : math.sin(loop * bobPeriod) * bobAmp;

    // Eye openness: 1 = wide, 0 = shut. Idle blinks; sleepy droops to ~0.35.
    final double baseOpen = switch (state) {
      OwlState.sleepy => 0.32,
      _ => 1.0,
    };
    double open = baseOpen;
    if (!reduce && state == OwlState.idle) {
      open = _blink(t);
    }
    // Ease openness across state transitions.
    open = _lerpFromNeutral(open);

    // Wing flap angle (radians) for cheer.
    final double flap =
        (!reduce && state == OwlState.cheer) ? math.sin(loop * 3) * 0.5 : 0.0;

    canvas.translate(0, bob);

    // --- Shadow ----------------------------------------------------------
    final shadow = Paint()
      ..color = AppColors.night900.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(100, 188 - bob),
        width: 96,
        height: 18,
      ),
      shadow,
    );

    // --- Wings (behind the body) ----------------------------------------
    _drawWing(
      canvas,
      _OwlPaths.wingLeft,
      pivot: const Offset(52, 100),
      angle: -flap,
    );
    _drawWing(
      canvas,
      _OwlPaths.wingRight,
      pivot: const Offset(148, 100),
      angle: flap,
    );

    // --- Body ------------------------------------------------------------
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.indigo400, AppColors.indigo500],
      ).createShader(const Rect.fromLTWH(40, 34, 120, 150));
    canvas.drawPath(_OwlPaths.body, bodyPaint);

    // Belly.
    canvas.drawPath(
      _OwlPaths.belly,
      Paint()..color = AppColors.night800.withValues(alpha: 0.55),
    );

    // Brow tufts.
    canvas.drawPath(_OwlPaths.browTufts, Paint()..color = AppColors.indigo500);

    // --- Face: eyes ------------------------------------------------------
    _drawEyes(canvas, open: open, loop: loop);

    // Beak.
    canvas.drawPath(_OwlPaths.beak, Paint()..color = AppColors.amber500);

    // Feet.
    canvas.drawPath(
      _OwlPaths.feet,
      Paint()
        ..color = AppColors.amber500
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // --- Sleepy "z" ------------------------------------------------------
    if (state == OwlState.sleepy) {
      _drawSleepyZ(canvas, t);
    }

    canvas.restore();
  }

  /// Natural double-blink: eyes wide most of the loop, two quick shuts.
  double _blink(double t) {
    // Two blink windows within the loop.
    for (final start in const [0.14, 0.24]) {
      final local = (t - start) / 0.05;
      if (local >= 0 && local <= 1) {
        // v-shape: open→shut→open.
        return (0.5 - local).abs() * 2;
      }
    }
    return 1.0;
  }

  /// Blend the target openness with the neutral (wide) pose during transitions
  /// so state changes don't pop.
  double _lerpFromNeutral(double target) {
    return _lerpDouble(1.0, target, transition);
  }

  void _drawWing(
    Canvas canvas,
    Path wing, {
    required Offset pivot,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      wing,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.indigo500, AppColors.night700],
        ).createShader(const Rect.fromLTWH(32, 96, 136, 70)),
    );
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, {required double open, required double loop}) {
    const leftEye = Offset(80, 92);
    const rightEye = Offset(120, 92);
    const eyeR = 20.0;

    final cheer = state == OwlState.cheer;

    for (final eye in const [leftEye, rightEye]) {
      // White (eye disc).
      canvas.drawCircle(eye, eyeR, Paint()..color = AppColors.ink);

      // Eyelids close from top & bottom based on (1 - open).
      final lid = (1 - open).clamp(0.0, 1.0);
      if (lid > 0.01) {
        final lidPaint = Paint()..color = AppColors.indigo500;
        final coverH = eyeR * lid;
        // Top lid.
        canvas.drawRect(
          Rect.fromLTRB(
            eye.dx - eyeR,
            eye.dy - eyeR,
            eye.dx + eyeR,
            eye.dy - eyeR + coverH,
          ),
          lidPaint,
        );
        // Bottom lid.
        canvas.drawRect(
          Rect.fromLTRB(
            eye.dx - eyeR,
            eye.dy + eyeR - coverH,
            eye.dx + eyeR,
            eye.dy + eyeR,
          ),
          lidPaint,
        );
      }

      if (open > 0.15) {
        // Pupil drifts subtly (idle) or is a sparkle (cheer).
        final drift = reduce ? Offset.zero : Offset(math.sin(loop) * 2, 0);
        final pupilCenter = eye + drift;
        if (cheer && !reduce) {
          _drawSparkle(canvas, pupilCenter, 8, AppColors.amber500);
        } else {
          canvas.drawCircle(
            pupilCenter,
            8 * open,
            Paint()..color = AppColors.night900,
          );
          // Catch-light.
          canvas.drawCircle(
            pupilCenter + const Offset(-3, -3),
            2.4 * open,
            Paint()..color = AppColors.ink,
          );
        }
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      path.moveTo(c.dx, c.dy);
      path.lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      path.lineTo(
        c.dx + math.cos(a + 0.4) * r * 0.35,
        c.dy + math.sin(a + 0.4) * r * 0.35,
      );
      path.close();
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(c, r * 0.28, paint);
  }

  void _drawSleepyZ(Canvas canvas, double t) {
    final rise = reduce ? 0.5 : (t % 1.0);
    final opacity = (1 - rise).clamp(0.0, 1.0);
    final dy = -rise * 34;
    final tp = TextPainter(
      text: TextSpan(
        text: 'z',
        style: TextStyle(
          color: AppColors.inkMuted.withValues(alpha: opacity),
          fontSize: 22 + rise * 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(132, 70 + dy));
  }

  @override
  bool shouldRepaint(covariant _OwlPainter old) =>
      old.state != state ||
      old.t != t ||
      old.transition != transition ||
      old.reduce != reduce;
}

/// Local double lerp (avoids importing dart:ui's lerpDouble null-return type).
double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
