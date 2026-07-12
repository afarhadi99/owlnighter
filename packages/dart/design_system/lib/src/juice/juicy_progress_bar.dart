import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// A thick, rounded progress bar with a lighter top-highlight stripe on the
/// fill — the chunky "juice" progression bar. The fill animates (and gives a
/// small pulse) whenever [value] increases; reduced motion snaps to the target.
///
/// [segments] optionally draws faint dividers to communicate a step count
/// (e.g. questions in a quiz).
class JuicyProgressBar extends StatefulWidget {
  const JuicyProgressBar({
    super.key,
    required this.value,
    this.height = 18,
    this.color = AppColors.successJuice,
    this.trackColor = AppColors.night700,
    this.segments,
  }) : assert(value >= 0 && value <= 1);

  /// 0.0 – 1.0.
  final double value;
  final double height;
  final Color color;
  final Color trackColor;

  /// If set (> 1), draws that many equal segment dividers over the track.
  final int? segments;

  @override
  State<JuicyProgressBar> createState() => _JuicyProgressBarState();
}

class _JuicyProgressBarState extends State<JuicyProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fill;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    _fill = AlwaysStoppedAnimation<double>(widget.value);
    _pulse = const AlwaysStoppedAnimation<double>(1);
  }

  @override
  void didUpdateWidget(covariant JuicyProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fill = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasized),
      );
      // A gentle pulse only when progress advances.
      final grew = widget.value > oldWidget.value;
      _pulse = grew
          ? TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 1, end: 1.06), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 1),
            ]).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            )
          : const AlwaysStoppedAnimation<double>(1);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = (reduce ? widget.value : _fill.value).clamp(0.0, 1.0);
        final scaleY = reduce ? 1.0 : _pulse.value;
        return Transform.scale(
          scaleY: scaleY,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: widget.height,
              child: CustomPaint(
                painter: _BarPainter(
                  value: v,
                  color: widget.color,
                  trackColor: widget.trackColor,
                  segments: widget.segments,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.segments,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final int? segments;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);

    // Track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );

    // Fill.
    final fillWidth = size.width * value;
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, radius),
        Paint()..color = color,
      );
      // Lighter top-highlight stripe across the top third of the fill.
      final stripeRect = Rect.fromLTWH(
        size.height * 0.25,
        size.height * 0.18,
        (fillWidth - size.height * 0.5).clamp(0.0, size.width),
        size.height * 0.28,
      );
      if (stripeRect.width > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            stripeRect,
            Radius.circular(size.height * 0.14),
          ),
          Paint()..color = const Color(0x66FFFFFF),
        );
      }
    }

    // Segment dividers.
    final segs = segments ?? 0;
    if (segs > 1) {
      final divider = Paint()
        ..color = AppColors.night900.withValues(alpha: 0.45)
        ..strokeWidth = 2;
      for (var i = 1; i < segs; i++) {
        final x = size.width * (i / segs);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), divider);
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.segments != segments;
}
