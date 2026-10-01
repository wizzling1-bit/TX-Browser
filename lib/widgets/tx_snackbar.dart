import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/spacing.dart';

/// TxSnackbar provides a centralized, browser-grade toast/snackbar system.
/// Adheres to Problem 35: consistent styling, dark green background,
/// subtle border, optional action button, and prevents duplicate queues.
class TxSnackbar {
  TxSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final colors = Theme.of(context).extension<TxColorScheme>();
    final surfaceColor = colors?.surface ?? const Color(0xFF111812);
    final borderColor = colors?.border ?? const Color(0xFF233226);
    final primaryColor = colors?.primary ?? const Color(0xFF9DC08B);
    final errorColor = colors?.error ?? const Color(0xFFFF5252);
    final textColor = colors?.textPrimary ?? const Color(0xFFF2F5F2);

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceColor,
        margin: const EdgeInsets.symmetric(
          horizontal: TxSpacing.lg,
          vertical: TxSpacing.md,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: TxSpacing.md,
          vertical: TxSpacing.sm + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError ? errorColor.withValues(alpha: 0.5) : borderColor,
            width: 1.1,
          ),
        ),
        elevation: 8,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isError ? errorColor : primaryColor,
              ),
              const SizedBox(width: TxSpacing.sm),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: TxSpacing.sm),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(44, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: isError ? errorColor : primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
