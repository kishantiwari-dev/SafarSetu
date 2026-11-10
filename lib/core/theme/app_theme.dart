import 'package:flutter/material.dart';

abstract final class AppColors {
  // Sampled visually from the supplied logo artwork.
  static const background = Color(0xFF0B203B);
  static const surface = Color(0xFF102944);
  static const surfaceRaised = Color(0xFF15334F);
  static const primaryText = Color(0xFFF4F6FA);
  static const secondaryText = Color(0xFFA9B9CD);
  static const accent = Color(0xFF16C5A8);
  static const accentBlue = Color(0xFF28A9CE);
  static const border = Color(0xFF29425C);
  static const error = Color(0xFFE58C91);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.accentBlue,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.primaryText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
