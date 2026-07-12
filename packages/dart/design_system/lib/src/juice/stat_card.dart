import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A bordered, rounded stat chip with a colored header band (the [label]) above
/// a big [value] — the completion-stat tile from the game-app pattern (TOTAL XP,
/// ACCURACY, STREAK, etc.), in our night-sky palette.
///
/// [value] is a widget so callers can drop in an [XpCounter], a flame, or plain
/// text. [accent] tints the header band and the border.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.amber500,
    this.icon,
    this.width,
  });

  final String label;
  final Widget value;
  final Color accent;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.night800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored header band.
          Container(
            width: double.infinity,
            color: accent.withValues(alpha: 0.22),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Big value.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: DefaultTextStyle(
              style: AppType.title.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
