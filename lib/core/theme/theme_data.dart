import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'shapes.dart';

/// Builds [ThemeData] for Tx Browser from design system tokens.
///
/// Dark mode is **not** an inversion of light mode. The primary/secondary
/// accent roles **swap** intentionally to maintain contrast against
/// darker backgrounds (DESIGN_SYSTEM.md §8).
class TxTheme {
  TxTheme._();

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------
  static ThemeData light() {
    const tokens = TxColorScheme.light;
    final textTheme = TxTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: ColorScheme.light(
        primary: tokens.primary,
        secondary: tokens.secondary,
        surface: tokens.surface,
        error: tokens.error,
        onPrimary: Colors.white,
        onSecondary: tokens.textPrimary,
        onSurface: tokens.textPrimary,
        onError: Colors.white,
        outline: tokens.border,
      ),
      textTheme: textTheme.apply(
        bodyColor: tokens.textPrimary,
        displayColor: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.bg,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineLarge?.copyWith(
          color: tokens.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusMd,
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusSheet,
        ),
        modalBarrierColor: tokens.overlayScrim,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : tokens.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.border;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusMd,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.bg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusSm,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: const [TxColorScheme.light],
    );
  }

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------
  static ThemeData dark() {
    const tokens = TxColorScheme.dark;
    final textTheme = TxTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: ColorScheme.dark(
        primary: tokens.primary,
        secondary: tokens.secondary,
        surface: tokens.surface,
        error: tokens.error,
        onPrimary: tokens.bg,
        onSecondary: tokens.textPrimary,
        onSurface: tokens.textPrimary,
        onError: Colors.white,
        outline: tokens.border,
      ),
      textTheme: textTheme.apply(
        bodyColor: tokens.textPrimary,
        displayColor: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.bg,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineLarge?.copyWith(
          color: tokens.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusMd,
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusSheet,
        ),
        modalBarrierColor: tokens.overlayScrim,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.bg
              : tokens.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.border;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusMd,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: TxRadius.borderRadiusSm,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: const [TxColorScheme.dark],
    );
  }
}
