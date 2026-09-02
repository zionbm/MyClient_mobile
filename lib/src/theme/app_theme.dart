import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0B4F52);
  static const primaryDark = Color(0xFF063B3E);
  static const primarySoft = Color(0xFF2F6B6D);
  static const primaryContainer = Color(0xFFD8ECEB);
  static const accent = Color(0xFFC84A35);
  static const background = Color(0xFFF7F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEEF2EF);
  static const ink = Color(0xFF172321);
  static const muted = Color(0xFF5F6F6C);
  static const border = Color(0xFFD8E0DC);
  static const success = Color(0xFF277A57);
  static const successContainer = Color(0xFFE3F3EB);
  static const warning = Color(0xFF9A6500);
  static const warningContainer = Color(0xFFFFF3D6);
  static const error = Color(0xFFB53A32);
  static const errorContainer = Color(0xFFFBE9E7);
  static const info = Color(0xFF356F9D);
  static const infoContainer = Color(0xFFE7F0F8);
  static const visit = info;
  static const quote = warning;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.accent,
          secondaryContainer: AppColors.errorContainer,
          surface: AppColors.surface,
          surfaceContainerLow: AppColors.surfaceAlt,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          outline: AppColors.border,
          error: AppColors.error,
          errorContainer: AppColors.errorContainer,
        ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size.square(48)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}
