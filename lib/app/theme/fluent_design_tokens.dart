import 'package:flutter/material.dart';

/// 集中保存 Pencil 设计稿提炼出的 Fluent 风格基础 token。
abstract final class FluentDesignTokens {
  static const Color primaryBlue = Color(0xFF005FB8);
  static const Color appBackground = Color(0xFFF3F3F3);
  static const Color titleBarBackground = Color(0xFFFBFBFB);
  static const Color navigationBackground = Color(0xFFF7F7F7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color fieldBackground = Color(0xFFF8F8F8);
  static const Color selectedBackground = Color(0xFFEAF3FF);
  static const Color previewBackground = Color(0xFF1F1F1F);
  static const Color canvasBackground = Color(0xFF2B2B2B);
  static const Color border = Color(0xFFDADADA);
  static const Color fieldBorder = Color(0xFFD1D1D1);
  static const Color textPrimary = Color(0xFF202020);
  static const Color textSecondary = Color(0xFF616161);
  static const Color warningBackground = Color(0xFFFFF8E5);
  static const Color warningBorder = Color(0xFFE5C365);
  static const Color warningText = Color(0xFF6A4F00);
  static const Color successGreen = Color(0xFF0E7A0D);
  static const Color errorRed = Color(0xFFC42B1C);
  static const Color closeHover = Color(0xFFC42B1C);

  static const double titleBarHeight = 48;
  static const double navigationWidth = 260;
  static const double pageGap = 14;
  static const double cardRadius = 10;
  static const double controlRadius = 6;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(28, 22, 28, 24);
  static const EdgeInsets navigationPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  static ThemeData materialTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      surface: cardBackground,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: appBackground,
      colorScheme: colorScheme.copyWith(
        primary: primaryBlue,
        surface: cardBackground,
        surfaceContainerHighest: fieldBackground,
        outline: fieldBorder,
        outlineVariant: border,
        error: errorRed,
      ),
      dividerColor: border,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 38),
          side: const BorderSide(color: fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: primaryBlue, width: 1.4),
        ),
      ),
    );
  }
}
