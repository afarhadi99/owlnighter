import 'package:flutter/widgets.dart';

/// Design tokens: the single source of truth for color, spacing, radius,
/// typography, and motion. Widgets and themes MUST read from here rather than
/// hard-coding values, so a rebrand touches one file.

/// Brand palette. Night-reading habit app → deep indigo night sky with a warm
/// amber "streak flame" accent.
abstract final class AppColors {
  // Night sky (primary surfaces).
  static const Color night900 = Color(0xFF0B1026);
  static const Color night800 = Color(0xFF141A3A);
  static const Color night700 = Color(0xFF1E2650);

  // Indigo brand.
  static const Color indigo500 = Color(0xFF5B6CFF);
  static const Color indigo400 = Color(0xFF7B89FF);

  // Warm accents (streaks / XP / rewards).
  static const Color amber500 = Color(0xFFFFB020);
  static const Color flame500 = Color(0xFFFF6B3D);

  // Semantic.
  static const Color success500 = Color(0xFF2FBF71);
  static const Color danger500 = Color(0xFFEF4E4E);

  // Neutrals.
  static const Color ink = Color(0xFFF4F5FB);
  static const Color inkMuted = Color(0xFFA6ACD6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color inkOnLight = Color(0xFF141A3A);
}

/// 4pt spacing scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

/// Type scale. Kept as [TextStyle] fragments so the theme composes them with a
/// resolved color for light/dark.
abstract final class AppType {
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
  );
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}

/// Motion tokens. Durations and curves are centralized so the whole app shares
/// one motion language and reduced-motion handling stays consistent.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration celebrate = Duration(milliseconds: 900);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve bounce = Curves.elasticOut;
}
