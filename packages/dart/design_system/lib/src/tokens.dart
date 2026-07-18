import 'package:flutter/widgets.dart';

/// Design tokens: the single source of truth for color, spacing, radius,
/// typography, and motion. Widgets and themes MUST read from here rather than
/// hard-coding values, so a rebrand touches one file.
///
/// Palette v3 — "cozy nocturnal gamification". Deep plum-indigo night, a warm
/// LAMP-GOLD reserved for the things you "keep lit" (streak flame, XP, completed
/// path nodes, rewards), and TWILIGHT-VIOLET for interaction. Every token NAME
/// from the previous amber/indigo palette is preserved so existing consumers
/// keep compiling — only the VALUES shifted, plus new semantic aliases
/// ([lamp], [lampGlow], [twilight], [twilightHi], [line], [night600], [faint],
/// [moon], [good], [bad]) were added.
abstract final class AppColors {
  // ── Night sky (primary surfaces) ─────────────────────────────────────────
  // Deep plum-indigo night, darkest → lighter.
  static const Color night900 = Color(0xFF0E0B1E);
  static const Color night800 = Color(0xFF151228);
  static const Color night700 = Color(0xFF1E1A38);

  /// A slightly raised night surface (tracks, disabled fills, inset wells).
  static const Color night600 = Color(0xFF272248);

  /// Hairline / border color that reads on the night surfaces.
  static const Color line = Color(0xFF322C55);

  // ── Twilight-violet (interaction / brand) ────────────────────────────────
  // The old "indigo" brand is now twilight-violet. Names preserved.
  static const Color indigo500 = Color(0xFF8E82F2); // twilight
  static const Color indigo400 = Color(0xFFA79CFF); // twilight-hi

  /// Semantic aliases for the interaction hue.
  static const Color twilight = indigo500;
  static const Color twilightHi = indigo400;

  // ── Lamp-gold (streaks / XP / rewards / "kept lit") ──────────────────────
  // The old warm "amber/flame" accents are now the lamp-gold family. Names
  // preserved; [flame500] maps to the deeper "glow" gold.
  static const Color amber500 = Color(0xFFFFCE7A); // lamp
  static const Color flame500 = Color(0xFFFFB347); // lamp-glow

  /// Semantic aliases for the warm "keep it lit" hue.
  static const Color lamp = amber500;
  static const Color lampGlow = flame500;

  // ── Semantic status ──────────────────────────────────────────────────────
  static const Color success500 = Color(0xFF52E0A6); // good
  static const Color danger500 = Color(0xFFFB6F7C); // bad

  /// Prototype-named aliases.
  static const Color good = success500;
  static const Color bad = danger500;

  // ── Juice kit ────────────────────────────────────────────────────────────
  // The game-app "juice" layer uses chunky 3D controls whose bottom edge is a
  // darker shade of the same hue. These are the face + edge pairs, re-derived
  // for the twilight/lamp palette.
  static const Color successJuice = Color(0xFF52E0A6); // chunky success face
  static const Color successJuiceEdge = Color(0xFF2F9E72); // darker bottom edge
  static const Color indigoEdge = Color(0xFF5648B0); // twilight bottom edge
  static const Color dangerEdge = Color(0xFFC74A56); // danger bottom edge
  static const Color amberEdge = Color(0xFFC98A2E); // lamp bottom edge
  static const Color disabledFill = Color(0xFF272248); // chunky disabled face
  static const Color disabledInk = Color(0xFF6E6796); // disabled label/icon

  // ── Neutrals / text ──────────────────────────────────────────────────────
  static const Color ink = Color(0xFFF3F0FF); // moon (primary text)
  static const Color inkMuted = Color(0xFF9E97C4); // muted (secondary text)

  /// The faintest legible text/iconography (captions, locked nodes).
  static const Color faint = Color(0xFF6E6796);

  /// Semantic alias for the primary "moonlight" text color.
  static const Color moon = ink;

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color inkOnLight = Color(0xFF151228);
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
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 30;
  static const double pill = 999;
}

/// Type scale. Kept as [TextStyle] fragments so the theme composes them with a
/// resolved color for light/dark.
///
/// The display / title / headline styles carry a storybook **serif** so book
/// titles and hero moments feel like a bedtime story; body / label / caption
/// stay in the system sans for legibility. No serif font file is bundled in the
/// repo, so we lean on the platform's generic `serif` family (Android resolves
/// this to Noto Serif on the emulator/devices) with graceful fallbacks.
abstract final class AppType {
  /// The storybook serif family. Generic `serif` maps to the platform serif
  /// (Noto Serif on Android); the fallbacks cover other platforms.
  static const String serifFamily = 'serif';
  static const List<String> serifFallback = <String>[
    'serif',
    'Georgia',
    'Times New Roman',
  ];

  static const TextStyle display = TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 0.2,
  );
  static const TextStyle title = TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 23,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );
}

/// Motion tokens. Durations and curves are centralized so the whole app shares
/// one motion language and reduced-motion handling stays consistent.
///
/// Curves mirror the prototype's calm bedtime easing: a soft standard settle and
/// a gentle spring for playful overshoot.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration celebrate = Duration(milliseconds: 900);

  /// Ambient breathing loop period (streak flame, pulsing "tonight" node).
  static const Duration breathe = Duration(milliseconds: 2600);

  /// Standard enter/settle — cubic-bezier(.2,.8,.25,1).
  static const Curve standard = Cubic(0.2, 0.8, 0.25, 1);

  /// Playful overshoot — cubic-bezier(.2,1.5,.4,1).
  static const Curve spring = Cubic(0.2, 1.5, 0.4, 1);

  static const Curve enter = standard;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = standard;
  static const Curve bounce = Curves.elasticOut;
}
