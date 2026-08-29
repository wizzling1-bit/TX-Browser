import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';
import 'buttons/tx_pressable.dart';

/// Premium Button variants.
enum PremiumButtonVariant { primary, secondary, destructive, ghost }

/// Commercial-grade tactile button with spring-scale physics.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (variant) {
      case PremiumButtonVariant.primary:
        backgroundColor = colors.primary;
        foregroundColor = Colors.white;
        break;
      case PremiumButtonVariant.secondary:
        backgroundColor = colors.surfaceAlt;
        foregroundColor = colors.primary;
        border = Border.all(
          color: colors.border,
          width: 1,
        );
        break;
      case PremiumButtonVariant.destructive:
        backgroundColor = colors.error.withValues(alpha: 0.12);
        foregroundColor = colors.error;
        border = Border.all(
          color: colors.error.withValues(alpha: 0.3),
          width: 1,
        );
        break;
      case PremiumButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.textPrimary;
        break;
    }

    final isEnabled = onPressed != null && !isLoading;

    return TxPressable(
      onTap: isEnabled ? onPressed : null,
      scaleDown: 0.96,
      child: Container(
        height: height,
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md),
        decoration: BoxDecoration(
          color: isEnabled
              ? backgroundColor
              : backgroundColor.withValues(alpha: 0.4),
          borderRadius: TxRadius.borderRadiusSm,
          border: border,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : Row(
                  mainAxisSize:
                      isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: foregroundColor),
                      const SizedBox(width: TxSpacing.sm),
                    ],
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
