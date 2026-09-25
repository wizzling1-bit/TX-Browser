import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../ads/tx_native_ad_card.dart';
import '../buttons/tx_button.dart';

/// Modal sheet shown when private browsing tabs are terminated.
class PrivateSessionEndedSheet extends StatelessWidget {
  const PrivateSessionEndedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrivateSessionEndedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: TxSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TxRadius.borderRadiusSheet,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: TxElevation.elevation3,
          ),
          padding: const EdgeInsets.all(TxSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: TxSpacing.md),

              // Shield Icon & Title
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.privateAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.privateAccent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.shieldCheck,
                        size: 24,
                        color: colors.privateAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Private Session Ended',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All private tabs closed & purged',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: TxSpacing.md),

              // Reassurance info banner
              Container(
                padding: const EdgeInsets.all(TxSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: TxRadius.borderRadiusSm,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.lock, size: 16, color: colors.privateAccent),
                    const SizedBox(width: TxSpacing.sm),
                    Expanded(
                      child: Text(
                        'Session cookies, temporary caches, and visited URLs were completely destroyed.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TxSpacing.md),

              // Embedded High-eCPM Native Ad
              const TxNativeAdCard(
                variant: TxAdSizeVariant.mediumRectangle,
                margin: EdgeInsets.zero,
              ),

              const SizedBox(height: TxSpacing.lg),

              // Action button
              TxButton(
                label: 'Return to Browser',
                variant: TxButtonVariant.primary,
                isFullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
