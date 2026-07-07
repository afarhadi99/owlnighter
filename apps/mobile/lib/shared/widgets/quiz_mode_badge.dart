import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../theme/theme_re_exports.dart';

/// Honesty badge: communicates how trustworthy a quiz is per the product rule
/// that we never claim page-level precision we cannot back with text.
class QuizModeBadge extends StatelessWidget {
  const QuizModeBadge({super.key, required this.mode});
  final QuizMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      QuizMode.grounded => ('Grounded', AppColors.success500),
      QuizMode.preview => ('Preview', AppColors.indigo400),
      QuizMode.userText => ('Your pages', AppColors.amber500),
      QuizMode.fallback => ('General', AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppType.caption.copyWith(color: color),
      ),
    );
  }
}
