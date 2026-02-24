/// ============================================================
/// NeuroVision — Shared Accessibility Theme
/// ============================================================
/// A high-contrast, dyslexia-friendly theme inherited by both
/// the Learning Module and the Vision Module.
///
/// Design principles:
///   • Large readable fonts (OpenDyslexic-style spacing)
///   • High-contrast colors (WCAG AAA compliant)
///   • Large touch targets (minimum 48dp)
///   • Minimal cognitive load — no distracting gradients
/// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ────────────────────────────────────────────────────────
// Color Palette — Dark, high-contrast, calming
// ────────────────────────────────────────────────────────
class NVColors {
  NVColors._(); // prevent instantiation

  // Primary surface colors
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1C2333);
  static const Color cardBorder = Color(0xFF30363D);

  // Accent colors
  static const Color primaryBlue = Color(0xFF58A6FF);
  static const Color primaryGreen = Color(0xFF3FB950);
  static const Color primaryOrange = Color(0xFFD29922);
  static const Color primaryRed = Color(0xFFF85149);
  static const Color primaryPurple = Color(0xFFBC8CFF);

  // Text colors — high contrast on dark backgrounds
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  // Module-specific accent colors
  static const Color learningAccent = Color(0xFF58A6FF); // Blue for learning
  static const Color visionAccent = Color(0xFF3FB950);   // Green for vision

  // Focus streak / gamification
  static const Color streakGold = Color(0xFFFFD700);
  static const Color badgeBronze = Color(0xFFCD7F32);
  static const Color badgeSilver = Color(0xFFC0C0C0);

  // Engagement feedback
  static const Color warningAmber = Color(0xFFFFA726);
  static const Color successGreen = Color(0xFF66BB6A);
  static const Color errorRed = Color(0xFFEF5350);
}

// ────────────────────────────────────────────────────────
// Shared Dimensions
// ────────────────────────────────────────────────────────
class NVDimensions {
  NVDimensions._();

  // Touch targets — minimum 48dp per accessibility guidelines
  static const double minTouchTarget = 56.0;
  static const double buttonHeight = 64.0;
  static const double largeTouchTarget = 80.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // Card
  static const double cardElevation = 0.0; // flat design, less distraction
  static const double borderWidth = 1.0;
}

// ────────────────────────────────────────────────────────
// Theme Builder
// ────────────────────────────────────────────────────────
class AccessibilityTheme {
  AccessibilityTheme._();

  /// Returns the app-wide [ThemeData].
  /// [fontScale] allows user-adjustable text sizing.
  static ThemeData buildTheme({double fontScale = 1.0}) {
    // Use Lexend — a font designed for improved reading proficiency,
    // especially beneficial for dyslexia.
    final baseTextTheme = GoogleFonts.lexendTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Scaffold & Surface ──
      scaffoldBackgroundColor: NVColors.background,
      canvasColor: NVColors.background,

      // ── Color Scheme ──
      colorScheme: const ColorScheme.dark(
        primary: NVColors.primaryBlue,
        secondary: NVColors.primaryGreen,
        surface: NVColors.surface,
        error: NVColors.primaryRed,
        onPrimary: NVColors.textPrimary,
        onSecondary: NVColors.textPrimary,
        onSurface: NVColors.textPrimary,
        onError: NVColors.textPrimary,
      ),

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: NVColors.surface,
        foregroundColor: NVColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: NVColors.surface,
        elevation: NVDimensions.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NVDimensions.radiusM),
          side: const BorderSide(
            color: NVColors.cardBorder,
            width: NVDimensions.borderWidth,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: NVDimensions.spacingM,
          vertical: NVDimensions.spacingS,
        ),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            double.infinity,
            NVDimensions.buttonHeight,
          ),
          backgroundColor: NVColors.primaryBlue,
          foregroundColor: NVColors.textPrimary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontSize: 18 * fontScale,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NVDimensions.spacingL,
            vertical: NVDimensions.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NVDimensions.radiusM),
          ),
          elevation: 0,
        ),
      ),

      // ── Text Theme — scaled for accessibility ──
      textTheme: TextTheme(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 32 * fontScale,
          fontWeight: FontWeight.w700,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 28 * fontScale,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 24 * fontScale,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w400,
          height: 1.8,          // generous line height for readability
          letterSpacing: 0.3,
          wordSpacing: 2.0,     // extra word spacing for dyslexia
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: NVColors.textSecondary,
          fontSize: 16 * fontScale,
          height: 1.6,
          letterSpacing: 0.2,
          wordSpacing: 1.5,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: NVColors.textPrimary,
          fontSize: 16 * fontScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // ── Icon ──
      iconTheme: const IconThemeData(
        color: NVColors.textPrimary,
        size: 28,
      ),

      // ── Progress Indicator ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NVColors.primaryBlue,
        linearTrackColor: NVColors.surfaceElevated,
        linearMinHeight: 8,
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: NVColors.cardBorder,
        thickness: 1,
        space: NVDimensions.spacingL,
      ),
    );
  }
}
