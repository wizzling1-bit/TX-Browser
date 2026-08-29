import 'package:flutter/material.dart';

/// Tx Browser motion tokens.
///
/// See DESIGN_SYSTEM.md §7.
///
/// All spring/stagger tokens collapse to a 100ms simple fade
/// when the OS reduced-motion accessibility setting is active.

class TxMotion {
  TxMotion._();

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// 100–150ms — button press feedback, toggle flip.
  static const microDuration = Duration(milliseconds: 120);

  /// 200–250ms — sheet open/close, address bar focus morph, segmented control.
  static const standardDuration = Duration(milliseconds: 220);

  /// 300–400ms — tab manager ↔ browser transition, bento stagger entrance.
  static const emphasisDuration = Duration(milliseconds: 350);

  /// 40ms — per-cell offset for bento entrance stagger.
  static const staggerStep = Duration(milliseconds: 40);

  /// Max cells to stagger before the rest appear together.
  static const staggerCap = 6;

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Standard ease-out for micro interactions.
  static const microCurve = Curves.easeOut;

  /// Spring-like medium bounce for standard transitions.
  static const standardCurve = Curves.easeOutCubic;

  /// Spring-like soft bounce for emphasis transitions.
  static const emphasisCurve = Curves.easeOutBack;

  // ---------------------------------------------------------------------------
  // Reduced Motion
  // ---------------------------------------------------------------------------

  /// Duration used when reduced motion is enabled (100ms simple fade).
  static const reducedDuration = Duration(milliseconds: 100);

  /// Curve used when reduced motion is enabled (simple ease).
  static const reducedCurve = Curves.easeOut;

  /// Check if reduced motion is requested by the OS.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get the appropriate duration based on reduced motion setting.
  static Duration duration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return isReducedMotion(context) ? reducedDuration : normalDuration;
  }

  /// Get the appropriate curve based on reduced motion setting.
  static Curve curve(
    BuildContext context,
    Curve normalCurve,
  ) {
    return isReducedMotion(context) ? reducedCurve : normalCurve;
  }
}
