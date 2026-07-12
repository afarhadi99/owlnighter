import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// Visual variants for [ChunkyButton].
enum ChunkyButtonVariant {
  /// Indigo brand fill — the default call-to-action.
  primary,

  /// Success green — "correct", "continue", "claim".
  success,

  /// Danger red — destructive / negative actions.
  danger,

  /// Bordered, transparent face — a lower-emphasis secondary action.
  outline,

  /// Text-only, no fill or border — the lowest-emphasis action.
  ghost,
}

/// THE signature control of the juice kit: a chunky, tactile button with a
/// darker same-hue bottom "edge" that gives it a 3D, physically-pressable look.
///
/// On tap-down the face translates down over the edge (the lip shrinks); on
/// release it springs back. A [HapticFeedback.lightImpact] fires on press. All
/// motion + haptics collapse to nothing under reduced motion, where the button
/// simply fires [onPressed].
///
/// Colors come from tokens only. The `outline`/`ghost` variants drop the edge
/// (they are visually flat) and are used for lower-emphasis actions.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ChunkyButtonVariant.primary,
    this.icon,
    this.fullWidth = false,
  });

  /// The button text. Rendered uppercase + bold in the chunky style.
  final String label;

  /// Tap handler. When null the button renders disabled (grey, no edge).
  final VoidCallback? onPressed;

  final ChunkyButtonVariant variant;

  /// Optional leading icon shown before the label.
  final IconData? icon;

  /// Stretch to the full width of the parent.
  final bool fullWidth;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  // The resting height of the 3D lip below the face.
  static const double _edgeHeight = 5;

  // How far the face sinks on press (a 2px lip remains).
  static const double _pressDepth = 3;

  ({Color face, Color edge, Color ink, Border? border}) get _palette {
    if (!_enabled) {
      return (
        face: AppColors.disabledFill,
        edge: AppColors.disabledFill,
        ink: AppColors.disabledInk,
        border: null,
      );
    }
    switch (widget.variant) {
      case ChunkyButtonVariant.primary:
        return (
          face: AppColors.indigo500,
          edge: AppColors.indigoEdge,
          ink: const Color(0xFFFFFFFF),
          border: null,
        );
      case ChunkyButtonVariant.success:
        return (
          face: AppColors.successJuice,
          edge: AppColors.successJuiceEdge,
          ink: const Color(0xFFFFFFFF),
          border: null,
        );
      case ChunkyButtonVariant.danger:
        return (
          face: AppColors.danger500,
          edge: AppColors.dangerEdge,
          ink: const Color(0xFFFFFFFF),
          border: null,
        );
      case ChunkyButtonVariant.outline:
        return (
          face: const Color(0x00000000),
          edge: const Color(0x00000000),
          ink: AppColors.indigo400,
          border: Border.all(color: AppColors.indigo500, width: 2),
        );
      case ChunkyButtonVariant.ghost:
        return (
          face: const Color(0x00000000),
          edge: const Color(0x00000000),
          ink: AppColors.indigo400,
          border: null,
        );
    }
  }

  bool get _hasEdge =>
      _enabled &&
      widget.variant != ChunkyButtonVariant.outline &&
      widget.variant != ChunkyButtonVariant.ghost;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  Future<void> _handleTap() async {
    if (!_enabled) return;
    if (!reduceMotionOf(context)) {
      await HapticFeedback.lightImpact();
    }
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final p = _palette;
    final double edge = _hasEdge ? _edgeHeight : 0;
    final bool sink = _pressed && _hasEdge && !reduce;

    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: p.ink),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppType.label.copyWith(
              color: p.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );

    // The face; padding reserves the lip so total height is constant whether
    // pressed or not — the face sinks by moving padding from bottom to top.
    final face = AnimatedPadding(
      duration: reduce ? Duration.zero : AppMotion.instant,
      curve: AppMotion.emphasized,
      padding: EdgeInsets.only(
        top: sink ? _pressDepth : 0,
        bottom: sink ? (edge - _pressDepth) : edge,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.face,
          border: p.border,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          child: content,
        ),
      ),
    );

    final stack = Stack(
      children: [
        if (_hasEdge)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.edge,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        face,
      ],
    );

    final sized = widget.fullWidth
        ? SizedBox(width: double.infinity, child: stack)
        : stack;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? _handleTap : null,
        child: sized,
      ),
    );
  }
}
