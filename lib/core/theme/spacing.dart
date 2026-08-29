/// Tx Browser spacing tokens.
///
/// See DESIGN_SYSTEM.md §3.
library;

class TxSpacing {
  TxSpacing._();

  /// 4dp — icon-to-label gaps.
  static const double xs = 4;

  /// 8dp — inner padding of chips / small controls.
  static const double sm = 8;

  /// 16dp — standard card padding, list row vertical padding.
  static const double md = 16;

  /// 24dp — section spacing, screen horizontal margins.
  static const double lg = 24;

  /// 32dp — major section breaks (e.g. between bento zones on Home).
  static const double xl = 32;

  /// 48dp — empty-state vertical centering offset.
  static const double xxl = 48;
}
