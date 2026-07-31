import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — brand colors and type styles.
class AppColors {
  static const primary = Color(0xFFEF3E23);
  static const black = Color(0xFF000000);
  static const background = Color(0xFFFFFFFF);
  static const teal = Color(0xFF2BBFB3);

  // Body / supporting text — fixes contrast failures on small text
  static const secondaryText = Color(0xFF616161);
  static const mutedText = Color(0xFF6B7280);
  static const borderColor = Color(0xFFD1D5DB);
  static const amber = Color(0xFFD97706);
}

class AppTextStyles {
  // Logo and main headings.
  static TextStyle heading({double? fontSize, FontWeight? fontWeight}) =>
      GoogleFonts.bagelFatOne(
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.normal,
        letterSpacing: -0.01, // -1%
      );

  // Body text and subtitles.
  static TextStyle body({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400, // Regular
  }) => GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle bodyMedium({double? fontSize}) =>
      body(fontSize: fontSize, fontWeight: FontWeight.w500); // Medium
}

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    error: AppColors.primary,
  ),
  textTheme: TextTheme(
    displayLarge: AppTextStyles.heading(fontSize: 57),
    displayMedium: AppTextStyles.heading(fontSize: 45),
    headlineLarge: AppTextStyles.heading(fontSize: 32),
    headlineMedium: AppTextStyles.heading(fontSize: 28),
    titleLarge: AppTextStyles.bodyMedium(fontSize: 22),
    bodyLarge: AppTextStyles.body(fontSize: 16),
    bodyMedium: AppTextStyles.body(fontSize: 14),
    bodySmall: AppTextStyles.body(fontSize: 13),
    labelSmall: AppTextStyles.bodyMedium(fontSize: 12),
  ),
);
