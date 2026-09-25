import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/tx_icons.dart';
import '../../state/notification_provider.dart';
import '../buttons/tx_button.dart';

/// Contextual bottom sheet explaining push notifications before requesting Android runtime permission.
class NotificationPermissionSheet extends ConsumerWidget {
  const NotificationPermissionSheet({super.key});

  /// Displays the bottom sheet if not already shown.
  static Future<void> showIfEligible(BuildContext context, WidgetRef ref) async {
    final state = ref.read(notificationSettingsProvider);
    if (state.onboardingPromptShown || state.permissionStatus == 'granted') {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationPermissionSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      padding: const EdgeInsets.all(TxSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TxRadius.lg)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: TxSpacing.lg),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.bell,
                color: colors.primary,
                size: 28,
              ),
            ),

            const SizedBox(height: TxSpacing.md),

            // Title
            Text(
              'Stay updated with TX Browser',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
            ),

            const SizedBox(height: TxSpacing.sm),

            // Subtitle
            Text(
              'Get timely notifications about completed downloads, new browser features, and important security advisories.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
            ),

            const SizedBox(height: TxSpacing.xl),

            // Action Buttons
            TxButton(
              label: 'Allow Notifications',
              isFullWidth: true,
              icon: LucideIcons.bell,
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .markOnboardingPromptShown();
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .requestPermission();
              },
            ),

            const SizedBox(height: TxSpacing.sm),

            TxButton(
              label: 'Not Now',
              variant: TxButtonVariant.ghost,
              isFullWidth: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .markOnboardingPromptShown();
              },
            ),
          ],
        ),
      ),
    );
  }
}
