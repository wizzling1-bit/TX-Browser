import 'package:flutter/material.dart';

/// Semantic design token system for Tx Browser.
///
/// Built around the authentic brand palette (#EDF1D6, #9DC08B, #609966, #40513B)
/// with a balanced neutral surface hierarchy — never flooding every surface green.
class TxColorScheme extends ThemeExtension<TxColorScheme> {
  const TxColorScheme({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderSubtle,
    required this.success,
    required this.error,
    required this.warning,
    required this.privateAccent,
    required this.overlayScrim,
    required this.glassSurface,
    required this.glassBorder,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderSubtle;
  final Color success;
  final Color error;
  final Color warning;
  final Color privateAccent;
  final Color overlayScrim;
  final Color glassSurface;
  final Color glassBorder;
  final bool isDark;

  // ---------------------------------------------------------------------------
  // Light Palette
  // ---------------------------------------------------------------------------
  static const light = TxColorScheme(
    bg: Color(0xFFF2F5E8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9EFE0),
    primary: Color(0xFF4A6B48),
    secondary: Color(0xFF7E9F76),
    textPrimary: Color(0xFF1D261C),
    textSecondary: Color(0xFF5F705C),
    textTertiary: Color(0xFF8E9E8C),
    border: Color(0xFFDFE6D5),
    borderSubtle: Color(0xFFECF0E6),
    success: Color(0xFF3F8A4B),
    error: Color(0xFFC0392B),
    warning: Color(0xFFD48325),
    privateAccent: Color(0xFF2E3D2A),
    overlayScrim: Color(0x661D261C),
    glassSurface: Color(0xD9FFFFFF),
    glassBorder: Color(0x66DFE6D5),
    isDark: false,
  );

  // ---------------------------------------------------------------------------
  // Dark Palette (Primary and Secondary accents swap deliberately)
  // ---------------------------------------------------------------------------
  static const dark = TxColorScheme(
    bg: Color(0xFF0D110E),
    surface: Color(0xFF131914),
    surfaceAlt: Color(0xFF1B221C),
    primary: Color(0xFF69A86E),
    secondary: Color(0xFF9DC08B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E9B8D),
    textTertiary: Color(0xFF617060),
    border: Color(0xFF1F2820),
    borderSubtle: Color(0xFF182019),
    success: Color(0xFF6BC27B),
    error: Color(0xFFE57373),
    warning: Color(0xFFFFB74D),
    privateAccent: Color(0xFF40513B),
    overlayScrim: Color(0x990A0E0A),
    glassSurface: Color(0xF2131914),
    glassBorder: Color(0x80222E23),
    isDark: true,
  );

  @override
  TxColorScheme copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? borderSubtle,
    Color? success,
    Color? error,
    Color? warning,
    Color? privateAccent,
    Color? overlayScrim,
    Color? glassSurface,
    Color? glassBorder,
    bool? isDark,
  }) {
    return TxColorScheme(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      privateAccent: privateAccent ?? this.privateAccent,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  TxColorScheme lerp(ThemeExtension<TxColorScheme>? other, double t) {
    if (other is! TxColorScheme) return this;
    return TxColorScheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      privateAccent: Color.lerp(privateAccent, other.privateAccent, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
