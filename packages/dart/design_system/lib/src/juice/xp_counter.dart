import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// A number that rolls up from a starting value to [value] with an ease-out
/// curve and a slight scale "pop" as it lands — the reward count-up from the
/// game-app pattern (XP earned, pages read).
///
/// Rolls from [from] to [value] on first build, and animates from the previous
/// [value] to the new one on update. Reduced motion shows the final value
/// immediately with no pop. An optional [prefix]/[suffix] frames the number
/// (e.g. "+", " XP").
class XpCounter extends StatefulWidget {
  const XpCounter({
    super.key,
    required this.value,
    this.from = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.color = AppColors.amber500,
    this.duration = AppMotion.celebrate,
  });

  final int value;
  final int from;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Color color;
  final Duration duration;

  @override
  State<XpCounter> createState() => _XpCounterState();
}

class _XpCounterState extends State<XpCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _count;
  late Animation<double> _pop;
  late int _begin;

  @override
  void initState() {
    super.initState();
    _begin = widget.from;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _buildAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant XpCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _begin = oldWidget.value;
      _buildAnimations();
      if (reduceMotionOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _buildAnimations() {
    _count = Tween<double>(
      begin: _begin.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Pop scale in the final ~20% of the roll.
    _pop = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 80),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final baseStyle = (widget.style ?? AppType.display).copyWith(
      color: widget.color,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final n = reduce ? widget.value : _count.value.round();
        final scale = reduce ? 1.0 : _pop.value;
        return Transform.scale(
          scale: scale,
          child: Text(
            '${widget.prefix}$n${widget.suffix}',
            style: baseStyle,
          ),
        );
      },
    );
  }
}
