import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../buttons/tx_button.dart';

/// Consistent, beautiful empty state widget.
class ImprovedEmptyState extends StatelessWidget {
  const ImprovedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TxSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with subtle gradient background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.15),
                    colors.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: TxSpacing.lg),
            
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TxSpacing.xs),
            
            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            
            // Actions
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TxSpacing.xl),
              TxButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: TxSpacing.sm),
              TxButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
                variant: TxButtonVariant.ghost,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
