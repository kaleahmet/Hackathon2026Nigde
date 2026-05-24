import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surface2 = Color(0xFF1A2236);
  static const Color surface3 = Color(0xFF222D44);
  static const Color primary = Color(0xFF00E5A0);
  static const Color primaryDim = Color(0xFF00B87D);
  static const Color accent = Color(0xFF00D4FF);
  static const Color danger = Color(0xFFFF4757);
  static const Color warn = Color(0xFFFFB347);
  static const Color safe = Color(0xFF00E5A0);
  static const Color text = Color(0xFFF0F4FF);
  static const Color text2 = Color(0xFF8B95B0);
  static const Color text3 = Color(0xFF5A6480);
  static const Color purple = Color(0xFF8B6DFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      cardColor: AppColors.surface,
      dividerColor: AppColors.surface3,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.text),
      ),
    );
  }

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        color: AppColors.text2,
        fontWeight: FontWeight.w500,
      );

  static const double cardRadius = 16.0;
}
