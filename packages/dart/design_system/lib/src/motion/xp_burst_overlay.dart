import 'package:flutter/material.dart';

import '../tokens.dart';

/// Fires a floating "+XP" badge that slides up and fades out over the current
/// screen using an [OverlayEntry] + Slide/Fade. Fire-and-forget: call
/// [XpBurst.show] from anywhere with a [BuildContext] that has an [Overlay]
/// ancestor (any Navigator/MaterialApp descendant qualifies).
abstract final class XpBurst {
  static void show(
    BuildContext context, {
    required int xp,
    Offset? origin,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => _XpBurstWidget(xp: xp, origin: origin),
    );
    overlay.insert(entry);
    // Remove after the animation window; the widget drives its own animation.
    Future<void>.delayed(AppMotion.celebrate + AppMotion.base, entry.remove);
  }
}

class _XpBurstWidget extends StatefulWidget {
  const _XpBurstWidget({required this.xp, this.origin});
  final int xp;
  final Offset? origin;

  @override
  State<_XpBurstWidget> createState() => _XpBurstWidgetState();
}

class _XpBurstWidgetState extends State<_XpBurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebrate,
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, -0.6),
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));

  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final origin = widget.origin ?? Offset(size.width / 2, size.height * 0.4);
    return Positioned(
      left: origin.dx - 60,
      top: origin.dy - 24,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: _badge(),
          ),
        ),
      ),
    );
  }

  Widget _badge() => Container(
        width: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.amber500,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber500.withValues(alpha: 0.5),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          '+${widget.xp} XP',
          style: AppType.label.copyWith(color: AppColors.night900),
        ),
      );
}
