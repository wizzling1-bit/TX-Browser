import 'package:flutter/material.dart';

import 'buttons/tx_button.dart';

export 'buttons/tx_button.dart' show TxButtonVariant;

/// Deprecated: Use [TxButton] directly. Maintained for backwards compatibility.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TxButtonVariant.primary,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final TxButtonVariant variant;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TxButton(
      label: label,
      onPressed: onPressed,
      variant: variant,
      icon: icon,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
    );
  }
}
