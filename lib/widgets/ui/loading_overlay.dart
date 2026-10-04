import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// Full-screen loading overlay with optional message.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
    this.showBackground = true,
  });

  final String? message;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      color: showBackground
          ? colors.overlayScrim
          : Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(TxSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: TxSpacing.md),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show loading overlay as a modal
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => LoadingOverlay(message: message),
    );
  }

  /// Hide loading overlay
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
