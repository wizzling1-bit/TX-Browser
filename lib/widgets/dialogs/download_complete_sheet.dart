import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/downloads_provider.dart';
import '../ads/tx_native_ad_card.dart';
import '../buttons/tx_button.dart';

/// Modern, policy-compliant modal bottom sheet shown when a download completes.
class DownloadCompleteSheet extends ConsumerWidget {
  const DownloadCompleteSheet({
    super.key,
    required this.download,
  });

  final DownloadModel download;

  static Future<void> show(BuildContext context, DownloadModel download) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DownloadCompleteSheet(download: download),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

              // Header Row: Success Badge + Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.checkCircle,
                        size: 22,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${download.fileName} • ${_formatBytes(download.sizeBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: colors.textTertiary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: TxSpacing.md),

              // Embedded High-eCPM Native Banner Ad
              const TxNativeAdCard(
                variant: TxAdSizeVariant.standardBanner,
                margin: EdgeInsets.zero,
              ),

              const SizedBox(height: TxSpacing.lg),

              // Action Buttons: Open File & Share
              Row(
                children: [
                  Expanded(
                    child: TxButton(
                      label: 'Share',
                      variant: TxButtonVariant.secondary,
                      icon: LucideIcons.share2,
                      onPressed: () {
                        if (download.filePath.isNotEmpty) {
                          SharePlus.instance.share(
                            ShareParams(
                              files: [XFile(download.filePath)],
                              subject: download.fileName,
                            ),
                          );
                        } else {
                          SharePlus.instance.share(
                            ShareParams(
                              text: download.fileName,
                              subject: download.fileName,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: TxButton(
                      label: 'Open File',
                      variant: TxButtonVariant.primary,
                      icon: LucideIcons.externalLink,
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(downloadsProvider.notifier).openDownload(download.id);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
