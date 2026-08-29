import 'package:flutter/material.dart';

/// Tx Browser shape & elevation tokens.
///
/// See DESIGN_SYSTEM.md §4.

class TxRadius {
  TxRadius._();

  /// 8dp — chips, small buttons, input fields.
  static const double sm = 8;

  /// 16dp — cards, bento cells, bottom sheets (top corners).
  static const double md = 16;

  /// 24dp — floating address bar, floating bottom nav pill.
  static const double lg = 24;

  /// 999dp — tab counter badge, FAB, segmented control thumb.
  static const double full = 999;

  // Convenience BorderRadius instances
  static final borderRadiusSm = BorderRadius.circular(sm);
  static final borderRadiusMd = BorderRadius.circular(md);
  static final borderRadiusLg = BorderRadius.circular(lg);
  static final borderRadiusFull = BorderRadius.circular(full);

  /// Bottom sheets: rounded top corners only.
  static const borderRadiusSheet = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
  );
}

/// Elevation presets using box shadows.
///
/// Shadow color uses brand-dark (`#40513B`) at varying opacities
/// to keep shadows warm/green-tinted rather than neutral grey.
class TxElevation {
  TxElevation._();

  static const _shadowColor = Color(0xFF1D261C);

  /// Level 0 — flat inline content, no shadow.
  static const List<BoxShadow> elevation0 = [];

  /// Level 1 — resting cards.
  /// 0/1/3 blur, 8% opacity brand-dark.
  static final List<BoxShadow> elevation1 = [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.08),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  /// Level 2 — floating nav/address bar, active tab card.
  /// 0/4/12 blur, 12% opacity.
  static final List<BoxShadow> elevation2 = [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// Level 3 — bottom sheets, dialogs.
  /// 0/8/24 blur, 16% opacity.
  static final List<BoxShadow> elevation3 = [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.16),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
