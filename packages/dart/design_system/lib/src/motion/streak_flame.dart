import 'package:flutter/material.dart';

import '../art/flame_flicker.dart';

/// The streak flame mascot.
///
/// This is now a thin adapter over [FlameFlicker] — the SVG-powered, layered,
/// organically-flickering flame in `src/art/` — so the app gets a real animated
/// flame with **no Rive binary asset** required. The public name and API
/// ([streakCount], [size], [isActive]) are preserved so existing call sites
/// keep working; internally the streak count is mapped to a flicker [intensity]
/// (a longer streak burns bigger and brighter, saturating around 30 days).
///
/// Reduced motion is handled by [FlameFlicker] itself (static, fully-formed
/// flame, no ticking controller).
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    required this.streakCount,
    this.size = 96,
  });

  final int streakCount;
  final double size;

  bool get isActive => streakCount > 0;

  /// Map streak length → 0..1 flame intensity. An active streak always burns at
  /// least a little (0.3) and saturates near a 30-day streak; a dead streak is
  /// a faint ember (0.06).
  double get _intensity {
    if (!isActive) return 0.06;
    return (0.3 + (streakCount / 30).clamp(0.0, 1.0) * 0.7).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return FlameFlicker(
      intensity: _intensity,
      size: size,
      semanticLabel: isActive
          ? 'Streak active, $streakCount ${streakCount == 1 ? 'day' : 'days'}'
          : 'Streak inactive',
    );
  }
}
