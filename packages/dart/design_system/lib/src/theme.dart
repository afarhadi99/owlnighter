import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the app [ThemeData] from tokens. The app is night-first (dark), but a
/// light theme is provided for accessibility / OS preference.
abstract final class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        surface: AppColors.night900,
        surfaceContainer: AppColors.night800,
        onSurface: AppColors.ink,
        onSurfaceMuted: AppColors.inkMuted,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        surface: const Color(0xFFF7F8FF),
        surfaceContainer: AppColors.surfaceLight,
        onSurface: AppColors.inkOnLight,
        onSurfaceMuted: const Color(0xFF5A6183),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color surface,
    required Color surfaceContainer,
    required Color onSurface,
    required Color onSurfaceMuted,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.indigo500,
      onPrimary: Colors.white,
      secondary: AppColors.amber500,
      onSecondary: AppColors.night900,
      tertiary: AppColors.flame500,
      onTertiary: Colors.white,
      error: AppColors.danger500,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainer,
      onSurfaceVariant: onSurfaceMuted,
    );

    TextStyle t(TextStyle s) => s.copyWith(color: onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: TextTheme(
        displaySmall: t(AppType.display),
        titleLarge: t(AppType.title),
        titleMedium: t(AppType.headline),
        bodyLarge: t(AppType.body),
        labelLarge: t(AppType.label),
        bodySmall: t(AppType.caption).copyWith(color: onSurfaceMuted),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      // Curved page transitions everywhere; reduced-motion is handled per-widget.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
