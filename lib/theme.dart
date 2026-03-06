import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF152B44);
  static const primaryLight = Color(0xFFE3E8EF);
  static const background = Color(0xFFF5F7FA);
  static const textMuted = Color(0xFF6B7B8D);
  static const border = Color(0xFFD5DAE0);
}

final ThemeData appTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.primaryLight,
    onSecondaryContainer: AppColors.primary,
    surface: Colors.white,
    onSurface: AppColors.primary,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    surfaceContainerLowest: AppColors.background,
  ),
);
