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
  // Durations (Crisp, snappy, and smooth)
  // ---------------------------------------------------------------------------

  /// 100ms — button press feedback, toggle flip.
  static const microDuration = Duration(milliseconds: 100);

  /// 180ms — sheet open/close, address bar focus morph, segmented control.
  static const standardDuration = Duration(milliseconds: 180);

  /// 240ms — tab manager ↔ browser transition, smooth entrance.
  static const emphasisDuration = Duration(milliseconds: 240);

  /// 30ms — per-cell offset for smooth stagger entrance.
  static const staggerStep = Duration(milliseconds: 30);

  /// Max cells to stagger before the rest appear together.
  static const staggerCap = 4;

  // ---------------------------------------------------------------------------
  // Curves (Smoothed ease-out curves, removing jarring bouncy overshoots)
  // ---------------------------------------------------------------------------

  /// Standard ease-out for micro interactions.
  static const microCurve = Curves.easeOut;

  /// Smooth ease-out for standard transitions.
  static const standardCurve = Curves.easeOutCubic;

  /// Smooth refined ease-out for emphasis transitions.
  static const emphasisCurve = Curves.easeOutCubic;

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
