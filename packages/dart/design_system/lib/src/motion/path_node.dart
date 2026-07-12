import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'reduced_motion.dart';

/// Visual state of a node on the reading path map.
///
/// [current] was added in v2 for the in-progress node (indigo with a progress
/// arc). It is additive — existing call sites that only produce
/// locked/available/completed keep working unchanged.
enum PathNodeStatus { locked, available, completed, current }

/// A single unlockable node on the reading path — v2.
///
/// The node is now a chunky 3D circle (a darker same-hue bottom edge, matching
/// [ChunkyButton]) that presses *down* on tap like a physical button. State:
///
/// * [PathNodeStatus.locked] — muted grey, lock glyph, not tappable.
/// * [PathNodeStatus.available] — indigo with a softly pulsing glow ring and a
///   floating "START" pill callout above the node that gently bobs.
/// * [PathNodeStatus.completed] — success green with a white check.
/// * [PathNodeStatus.current] — indigo with a progress arc drawn from
///   [progress] (0–1).
///
/// The original constructor ([status], [label], [onTap], [diameter]) is
/// unchanged; [progress] and [startLabel] are new optional params. All motion
/// (pulse, bob, press) collapses under reduced motion.
class PathNode extends StatefulWidget {
  const PathNode({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
    this.diameter = 64,
    this.progress = 0,
    this.startLabel = 'START',
  });

  final PathNodeStatus status;
  final String label;
  final VoidCallback? onTap;
  final double diameter;

  /// Progress arc fill (0–1) for [PathNodeStatus.current].
  final double progress;

  /// Localizable text for the floating callout pill on an available node.
  final String startLabel;

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _pressed = false;

  static const double _edge = 6;
  static const double _pressDepth = 4;

  @override
  void initState() {
    super.initState();
    // One shared loop drives both the glow pulse and the callout bob. It is
    // only started (see [_syncAnimation]) for the states that need it and when
    // reduced motion is off — otherwise it stays idle so pumpAndSettle / a
    // static render behave correctly.
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant PathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _syncAnimation();
  }

  /// Runs the pulse/bob loop only for animated states with motion enabled.
  void _syncAnimation() {
    final animate = !reduceMotionOf(context) &&
        (widget.status == PathNodeStatus.available ||
            widget.status == PathNodeStatus.current);
    if (animate && !_loop.isAnimating) {
      _loop.repeat(reverse: true);
    } else if (!animate && _loop.isAnimating) {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  bool get _isLocked => widget.status == PathNodeStatus.locked;
  bool get _tappable => !_isLocked && widget.onTap != null;

  ({Color face, Color edge}) get _palette => switch (widget.status) {
        PathNodeStatus.locked => (
            face: AppColors.night700,
            edge: AppColors.night900,
          ),
        PathNodeStatus.available => (
            face: AppColors.indigo500,
            edge: AppColors.indigoEdge,
          ),
        PathNodeStatus.current => (
            face: AppColors.indigo500,
            edge: AppColors.indigoEdge,
          ),
        PathNodeStatus.completed => (
            face: AppColors.successJuice,
            edge: AppColors.successJuiceEdge,
          ),
      };

  IconData get _glyph => switch (widget.status) {
        PathNodeStatus.locked => Icons.lock_outline,
        PathNodeStatus.available => Icons.menu_book_rounded,
        PathNodeStatus.current => Icons.auto_stories_rounded,
        PathNodeStatus.completed => Icons.check_rounded,
      };

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  Future<void> _handleTap() async {
    if (!_tappable) return;
    if (!reduceMotionOf(context)) {
      await HapticFeedback.lightImpact();
    }
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final p = _palette;
    final d = widget.diameter;
    final sink = _pressed && !reduce && !_isLocked;

    // The 3D circle: a darker edge circle behind, the face on top, offset up by
    // the lip. On press the face sinks toward the edge.
    final circle = SizedBox(
      width: d,
      height: d + _edge,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final t = reduce ? 0.0 : _loop.value;
          final faceTop = sink ? _pressDepth : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Bottom edge circle.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    color: p.edge,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Face circle.
              Positioned(
                left: 0,
                right: 0,
                top: faceTop,
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    color: p.face,
                    shape: BoxShape.circle,
                    boxShadow: _isLocked
                        ? null
                        : [
                            BoxShadow(
                              color: p.face.withValues(
                                alpha: 0.35 + (t * 0.25),
                              ),
                              blurRadius: 14 + (t * 8),
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _glyph,
                    color: _isLocked ? AppColors.inkMuted : Colors.white,
                    size: d * 0.42,
                    semanticLabel: widget.label,
                  ),
                ),
              ),
              // Progress arc for the current node.
              if (widget.status == PathNodeStatus.current)
                Positioned(
                  left: 0,
                  right: 0,
                  top: faceTop,
                  child: SizedBox(
                    width: d,
                    height: d,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        progress: widget.progress.clamp(0.0, 1.0),
                        color: AppColors.amber500,
                        stroke: 5,
                      ),
                    ),
                  ),
                ),
              // Pulsing glow ring for the available node.
              if (widget.status == PathNodeStatus.available && !reduce)
                Positioned(
                  left: 0,
                  right: 0,
                  top: faceTop,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: d + (t * 14),
                        height: d + (t * 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.indigo400.withValues(
                              alpha: 0.6 * (1 - t),
                            ),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    final node = Semantics(
      button: _tappable,
      enabled: !_isLocked,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _tappable ? (_) => _setPressed(true) : null,
        onTapUp: _tappable ? (_) => _setPressed(false) : null,
        onTapCancel: _tappable ? () => _setPressed(false) : null,
        onTap: _tappable ? _handleTap : null,
        child: circle,
      ),
    );

    // Available nodes get a floating, bobbing START callout above them.
    if (widget.status != PathNodeStatus.available) return node;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _loop,
          builder: (context, child) {
            final dy = reduce ? 0.0 : (math.sin(_loop.value * math.pi) * -4);
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: _StartPill(text: widget.startLabel),
        ),
        const SizedBox(height: AppSpacing.xs),
        node,
      ],
    );
  }
}

/// The floating "START" callout pill above an available node.
class _StartPill extends StatelessWidget {
  const _StartPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppType.caption.copyWith(
          color: AppColors.indigo500,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}
