import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../ads/tx_native_ad_card.dart';
import '../buttons/tx_button.dart';

/// Modal dialog shown after browsing history, cookies, or cache are cleaned.
class CacheCleanedDialog extends StatelessWidget {
  const CacheCleanedDialog({
    super.key,
    this.reclaimedMb = 28.4,
  });

  final double reclaimedMb;

  static Future<void> show(BuildContext context, {double reclaimedMb = 28.4}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CacheCleanedDialog(reclaimedMb: reclaimedMb),
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

              // Sparkle Icon & Cleaned Status
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.checkCircle,
                        size: 24,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Browsing Data Purged',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Storage & privacy successfully reclaimed',
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

              // Cleanup Summary Chip Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: TxSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: TxRadius.borderRadiusSm,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBadge(
                      label: 'Cache Freed',
                      value: '~${reclaimedMb.toStringAsFixed(1)} MB',
                      colors: colors,
                    ),
                    Container(width: 1, height: 24, color: colors.borderSubtle),
                    _StatBadge(
                      label: 'Cookies',
                      value: 'Cleared',
                      colors: colors,
                    ),
                    Container(width: 1, height: 24, color: colors.borderSubtle),
                    _StatBadge(
                      label: 'History',
                      value: 'Reset',
                      colors: colors,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TxSpacing.md),

              // High-eCPM Embedded Native Ad
              const TxNativeAdCard(
                variant: TxAdSizeVariant.mediumRectangle,
                margin: EdgeInsets.zero,
              ),

              const SizedBox(height: TxSpacing.lg),

              // Done Button
              TxButton(
                label: 'Done',
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

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
