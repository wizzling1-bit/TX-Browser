import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tx Browser typography tokens.
///
/// Uses Inter as the primary typeface and JetBrains Mono for
/// URL / data display. See DESIGN_SYSTEM.md §2.
///
/// Type scale ratio: ~1.125 (major second) — calm hierarchy,
/// not dramatic. "Linear-level precision."

class TxTypography {
  TxTypography._();

  /// Display — onboarding headlines, empty-state headers.
  /// 28–34sp, weight 600–700, line-height 1.15.
  static TextStyle display(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Heading — screen titles ("History," "Settings"), section headers.
  /// 20–22sp, weight 600, line-height 1.25.
  static TextStyle heading(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.1,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Body — list rows, settings labels, body copy.
  /// 15–16sp, weight 400–500, line-height 1.4.
  static TextStyle body(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Body medium — slightly bolder body for emphasis.
  static TextStyle bodyMedium(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Label — section eyebrows, button labels, chips.
  /// 12–13sp, weight 500, line-height 1.3.
  static TextStyle label(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Label uppercase — for true section eyebrows only (e.g. "PRIVACY & SECURITY").
  static TextStyle labelUppercase(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Mono / Data — URLs in address bar, file sizes, timestamps.
  /// 13–14sp, weight 400–500, line-height 1.3.
  static TextStyle mono(BuildContext context) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Mono medium — slightly bolder mono for data emphasis.
  static TextStyle monoMedium(BuildContext context) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  // ---------------------------------------------------------------------------
  // Base TextTheme for ThemeData construction
  // ---------------------------------------------------------------------------

  static TextTheme textTheme() => TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.15,
          letterSpacing: -0.3,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -0.2,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.1,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.8,
        ),
      );
}
