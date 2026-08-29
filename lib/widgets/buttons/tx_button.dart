import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import 'tx_pressable.dart';

/// Tx Browser button variants per DESIGN_SYSTEM.md §5.5.
enum TxButtonVariant { primary, secondary, destructive, ghost }

class TxButton extends StatelessWidget {
  const TxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TxButtonVariant.primary,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TxButtonVariant variant;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (variant) {
      case TxButtonVariant.primary:
        backgroundColor = colors.primary;
        foregroundColor = Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF7F8EB)
            : colors.bg;
        break;
      case TxButtonVariant.secondary:
        backgroundColor = colors.secondary.withValues(alpha: 0.18);
        foregroundColor = colors.primary;
        border = Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: 1,
        );
        break;
      case TxButtonVariant.destructive:
        backgroundColor = colors.error.withValues(alpha: 0.15);
        foregroundColor = colors.error;
        border = Border.all(
          color: colors.error.withValues(alpha: 0.4),
          width: 1,
        );
        break;
      case TxButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.textPrimary;
        break;
    }

    final isEnabled = onPressed != null && !isLoading;

    return TxPressable(
      onTap: isEnabled ? onPressed : null,
      scaleDown: 0.97,
      child: Container(
        height: 48,
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
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: foregroundColor,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Icon-only button with 48dp minimum touch target.
class TxIconButton extends StatelessWidget {
  const TxIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 22,
    this.color,
    this.isEnabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final Color? color;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: isEnabled && onPressed != null,
      child: TxPressable(
        onTap: isEnabled ? onPressed : null,
        scaleDown: 0.88,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: isEnabled && onPressed != null
                  ? (color ?? colors.textPrimary)
                  : colors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
