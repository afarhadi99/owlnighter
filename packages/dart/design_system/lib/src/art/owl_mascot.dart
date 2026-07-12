import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// Behavioural states for [OwlMascot].
enum OwlState {
  /// Gentle breathing bob with a jittered, natural blink cadence and rare
  /// micro head-tilts.
  idle,

  /// Wing flap + upward bounce + bright, sparkling eyes (celebration).
  cheer,

  /// Half-closed eyes, slow bob, a floating "z" — bedtime mood.
  sleepy,

  /// Friendly one-shot "peek": the owl bobs up to say hello with sparkling
  /// eyes, then settles. Ideal for empty states / greetings. Additive — added
  /// after the original three and never reordered.
  greet,

  /// Mild concern — furrowed "worried" eyebrows over wide, attentive eyes.
  /// For nudging that it's getting late and tonight's lesson hasn't been
  /// done yet. Additive — added after [greet] and never reordered.
  worried,

  /// Frustrated / insistent — squinted, glaring eyes under a furrowed frown
  /// and a small tense shake. For when tonight's lesson was skipped.
  /// Additive — added after [worried] and never reordered.
  angry,
}

/// A charming owl mascot assembled from hand-authored SVG path layers (body,
/// belly, wings, brow tufts, eyes, pupils, beak, feet) and animated with a
/// single [CustomPainter]. All paths are authored in a 200x200 viewbox and
/// scaled to [size].
///
/// The owl reacts to [state]:
/// * [OwlState.idle] — breathes (subtle vertical bob + belly scale) and blinks
///   on a **jittered, non-periodic** cadence, with occasional (every ~6-10s)
///   brief head-tilt micro-motions so it never feels robotic.
/// * [OwlState.cheer] — flaps its wings, bounces, pupils turn to sparkles.
/// * [OwlState.sleepy] — eyes droop to half, the bob slows, and a "z" drifts up.
/// * [OwlState.greet] — peeks up once with sparkling eyes then settles.
/// * [OwlState.worried] — wide eyes under concerned eyebrows (inner end
///   raised, outer end lowered) — mild "getting late" concern.
/// * [OwlState.angry] — squinted, glaring eyes under furrowed eyebrows
///   (inner end lowered, outer end raised) with a quick, tight side-to-side
///   shake — frustrated/insistent.
///
/// Reduced motion → a static owl posed for the current state (open, charming
/// eyes for idle/cheer/greet, drooped eyes for sleepy, wide concerned eyes
/// for worried, squinted glaring eyes for angry) with no ticking controller,
/// no jitter, and no shake. Colours are pulled from [AppColors]; nothing is
/// hard-coded.
///
/// A fixed [random] may be injected for deterministic tests of the jittered
/// idle behaviour; when omitted a fresh [math.Random] is used so the timing is
/// naturally varied in production.
class OwlMascot extends StatefulWidget {
  const OwlMascot({
    super.key,
    this.state = OwlState.idle,
    this.size = 160,
    this.semanticLabel = 'Owl mascot',
    this.random,
  });

  final OwlState state;
  final double size;
  final String semanticLabel;

  /// Optional seedable source for the idle jitter (blink cadence + micro-tilt
  /// timing). Additive: defaults to a fresh [math.Random] which preserves the
  /// prior lifelike-but-varied behaviour for every existing call site.
  final math.Random? random;

  @override
  State<OwlMascot> createState() => _OwlMascotState();
}

class _OwlMascotState extends State<OwlMascot> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  // Eased 0..1..0 value driving state transitions (eye droop, wing rest angle,
  // greet peek).
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
    value: 1,
  );

  late final _IdleTimeline _idle =
      _IdleTimeline(widget.random ?? math.Random());

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
              // Advance the jittered idle timeline from the master clock. Done
              // here (not setState) so it rides the existing per-frame repaint;
              // it is delta-based on the controller value, so extra rebuilds in
              // the same frame are no-ops.
              double idleOpen = 1.0;
              double idleTilt = 0.0;
              if (!reduce && widget.state == OwlState.idle) {
                _idle.advance(_controller.value);
                idleOpen = _idle.eyeOpen;
                idleTilt = _idle.headTilt;
              }
              return CustomPaint(
                painter: _OwlPainter(
                  state: widget.state,
                  t: reduce ? 0 : _controller.value,
                  transition: _transition.value,
                  reduce: reduce,
                  idleOpen: idleOpen,
                  headTilt: idleTilt,
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

/// Drives the idle owl's non-periodic blink cadence and rare micro head-tilts.
///
/// Advanced by [advance] with the master [AnimationController]'s 0..1 value; it
/// integrates the wrapped delta into a monotonic seconds clock (the controller
/// loops every 4s) and schedules the next blink / micro-tilt with jitter drawn
/// from the injected [math.Random]. This makes the behaviour fully
/// deterministic for a seeded random, which the tests rely on.
class _IdleTimeline {
  _IdleTimeline(this._rng) {
    // First blink 1-3s in; first micro-tilt 6-10s in.
    _blinkStart = 1.0 + _rng.nextDouble() * 2.0;
    _isDouble = _rng.nextDouble() < 0.35;
    _microStart = 6.0 + _rng.nextDouble() * 4.0;
    _microAmp = _pickMicroAmp();
  }

  final math.Random _rng;

  static const double _controllerSeconds = 4.0;
  static const double _blinkHalf = 0.16; // one open→shut→open dip
  static const double _doubleGap = 0.08; // pause between the two dips
  static const double _microDur = 0.7; // head-tilt in-out window

  double _seconds = 0.0;
  double _lastValue = 0.0;
  bool _seeded = false;

  double _blinkStart = 0.0;
  bool _isDouble = false;

  double _microStart = 0.0;
  double _microAmp = 0.0;

  double _pickMicroAmp() {
    // 0.045..0.09 rad (~2.5-5deg), random left/right.
    final mag = 0.045 + _rng.nextDouble() * 0.045;
    return _rng.nextBool() ? mag : -mag;
  }

  void advance(double controllerValue) {
    if (!_seeded) {
      _lastValue = controllerValue;
      _seeded = true;
      return;
    }
    // Wrapped forward delta in 0..1, scaled to real seconds.
    final frac = ((controllerValue - _lastValue) % 1.0 + 1.0) % 1.0;
    _lastValue = controllerValue;
    _seconds += frac * _controllerSeconds;

    // Reschedule a finished blink.
    final blinkLen = _isDouble ? (_blinkHalf * 2 + _doubleGap) : _blinkHalf;
    if (_seconds - _blinkStart > blinkLen) {
      _blinkStart = _seconds + 2.0 + _rng.nextDouble() * 3.5; // 2.0-5.5s gap
      _isDouble = _rng.nextDouble() < 0.35;
    }

    // Reschedule a finished micro-tilt.
    if (_seconds - _microStart > _microDur) {
      _microStart = _seconds + 6.0 + _rng.nextDouble() * 4.0; // 6-10s gap
      _microAmp = _pickMicroAmp();
    }
  }

  /// Eye openness 0..1 (1 = wide). V-shaped dip(s) during a blink window.
  double get eyeOpen {
    final local = _seconds - _blinkStart;
    if (local < 0) return 1.0;
    if (local <= _blinkHalf) return (0.5 - local / _blinkHalf).abs() * 2;
    if (_isDouble) {
      final l2 = local - (_blinkHalf + _doubleGap);
      if (l2 >= 0 && l2 <= _blinkHalf) {
        return (0.5 - l2 / _blinkHalf).abs() * 2;
      }
    }
    return 1.0;
  }

  /// Head-tilt angle in radians; a brief sinusoidal in-out, else 0.
  double get headTilt {
    final local = _seconds - _microStart;
    if (local < 0 || local > _microDur) return 0.0;
    return math.sin(local / _microDur * math.pi) * _microAmp;
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
    required this.idleOpen,
    required this.headTilt,
  });

  final OwlState state;
  final double t; // 0..1 master loop
  final double transition; // 0..1 state-transition ease
  final bool reduce;
  final double idleOpen; // jittered idle eye openness (idle only)
  final double headTilt; // jittered idle micro-tilt in radians (idle only)

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
      OwlState.greet => 1.2,
      OwlState.worried => 0.9,
      OwlState.angry => 0.35,
    };
    final double bobAmp = switch (state) {
      OwlState.idle => 3.0,
      OwlState.cheer => 9.0,
      OwlState.sleepy => 2.0,
      OwlState.greet => 3.0,
      OwlState.worried => 2.0,
      OwlState.angry => 1.5,
    };
    var bob = reduce ? 0.0 : math.sin(loop * bobPeriod) * bobAmp;

    // Greet peek: a one-shot rise-and-settle driven by the transition ease.
    if (state == OwlState.greet && !reduce) {
      bob += math.sin(transition * math.pi) * -16.0;
    }

    // Eye openness: 1 = wide, 0 = shut. Idle uses the jittered timeline; sleepy
    // droops to ~0.32.
    final double baseOpen = switch (state) {
      OwlState.sleepy => 0.32,
      OwlState.angry => 0.6,
      _ => 1.0,
    };
    double open = baseOpen;
    if (!reduce && state == OwlState.idle) {
      open = idleOpen;
    }
    // Ease openness across state transitions.
    open = _lerpFromNeutral(open);

    // Wing flap angle (radians) for cheer.
    final double flap =
        (!reduce && state == OwlState.cheer) ? math.sin(loop * 3) * 0.5 : 0.0;

    // Angry: a small, tense side-to-side shake (never during reduced motion).
    final double shake =
        (!reduce && state == OwlState.angry) ? math.sin(loop * 10) * 1.2 : 0.0;

    canvas.translate(shake, bob);

    // --- Shadow (drawn before the head-tilt so it stays grounded) --------
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

    // Idle micro head-tilt: rotate the owl (not its shadow) around its middle.
    final applyTilt = !reduce && state == OwlState.idle && headTilt != 0.0;
    if (applyTilt) {
      canvas.save();
      canvas.translate(100, 120);
      canvas.rotate(headTilt);
      canvas.translate(-100, -120);
    }

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
    _drawEyebrows(canvas);

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

    if (applyTilt) canvas.restore();

    canvas.restore();
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

    // Sparkling eyes for the celebratory / greeting states.
    final sparkleEyes = state == OwlState.cheer || state == OwlState.greet;

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
        // Pupil drifts subtly (idle) or is a sparkle (cheer/greet).
        final drift = reduce ? Offset.zero : Offset(math.sin(loop) * 2, 0);
        final pupilCenter = eye + drift;
        if (sparkleEyes && !reduce) {
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

  /// Furrowed (angry) or concerned (worried) eyebrows, drawn directly above
  /// each eye disc. No-op for every other state.
  void _drawEyebrows(Canvas canvas) {
    if (state != OwlState.angry && state != OwlState.worried) return;

    final paint = Paint()
      ..color = AppColors.night900
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (state == OwlState.angry) {
      // Inner end lower, outer end higher — a furrowed "V" frown.
      canvas.drawLine(const Offset(64, 68), const Offset(86, 80), paint);
      canvas.drawLine(const Offset(114, 80), const Offset(136, 68), paint);
    } else {
      // Worried: inner end higher, outer end lower — concerned brows.
      canvas.drawLine(const Offset(64, 80), const Offset(86, 66), paint);
      canvas.drawLine(const Offset(114, 66), const Offset(136, 80), paint);
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
      old.reduce != reduce ||
      old.idleOpen != idleOpen ||
      old.headTilt != headTilt;
}

/// Local double lerp (avoids importing dart:ui's lerpDouble null-return type).
double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
