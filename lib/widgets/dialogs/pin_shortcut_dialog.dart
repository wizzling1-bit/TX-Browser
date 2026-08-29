import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../state/acquisition_provider.dart';
import '../buttons/tx_button.dart';

/// Shows an elegant dialog offering the user to pin the target website as an Android launcher shortcut.
Future<bool> showPinShortcutDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String url,
}) async {
  final isSupported =
      await ref.read(acquisitionServiceProvider).isPinShortcutSupported();
  if (!isSupported || !context.mounted) return false;

  final colors = Theme.of(context).extension<TxColorScheme>()!;
  final host = Uri.tryParse(url)?.host.replaceAll('www.', '') ?? title;

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TxSpacing.xl,
          TxSpacing.lg,
          TxSpacing.xl,
          TxSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top drag pill
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: TxSpacing.lg),

            // Emblem Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.smartphone,
                size: 26,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: TxSpacing.md),

            // Title
            Text(
              'Pin to Home Screen?',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
            ),
            const SizedBox(height: TxSpacing.xs),

            // Description
            Text(
              'Add $host as a 1-tap shortcut on your Android launcher.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: TxSpacing.xl),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TxSpacing.md),
                Expanded(
                  flex: 2,
                  child: TxButton(
                    label: 'Pin Shortcut',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (result == true) {
    return ref.read(acquisitionServiceProvider).requestLauncherPin(
          title: title.isNotEmpty ? title : host,
          url: url,
        );
  }

  return false;
}
