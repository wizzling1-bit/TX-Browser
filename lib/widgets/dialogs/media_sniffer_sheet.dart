import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/downloads_provider.dart';
import '../../state/media_sniffer_provider.dart';
import '../buttons/tx_button.dart';
import '../tx_snackbar.dart';

/// Modal bottom sheet listing detected media files ready for 1-tap download.
class MediaSnifferSheet extends ConsumerWidget {
  const MediaSnifferSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MediaSnifferSheet(),
    );
  }

  Future<void> _downloadItem(
    BuildContext context,
    WidgetRef ref,
    SniffedMedia media,
  ) async {
    HapticFeedback.selectionClick();
    String? cookiesStr;
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(media.url),
      );
      if (cookies.isNotEmpty) {
        cookiesStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      }
    } catch (_) {}

    ref.read(downloadsProvider.notifier).startDownload(
          media.url,
          customFileName: media.fileName,
          mimeType: media.mimeType,
          userAgent: 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          cookies: cookiesStr,
        );

    if (context.mounted) {
      TxSnackbar.show(
        context,
        'Downloading: ${media.fileName}',
        icon: LucideIcons.download,
      );
    }
  }

  Future<void> _downloadAll(
    BuildContext context,
    WidgetRef ref,
    List<SniffedMedia> items,
  ) async {
    HapticFeedback.mediumImpact();
    final downloadable = items.where((i) => !i.isPolicyBlocked).toList();
    if (downloadable.isEmpty) return;

    for (final media in downloadable) {
      String? cookiesStr;
      try {
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri(media.url),
        );
        if (cookies.isNotEmpty) {
          cookiesStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        }
      } catch (_) {}

      ref.read(downloadsProvider.notifier).startDownload(
            media.url,
            customFileName: media.fileName,
            mimeType: media.mimeType,
            userAgent: 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
            cookies: cookiesStr,
          );
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      TxSnackbar.show(
        context,
        'Started ${downloadable.length} downloads',
        icon: LucideIcons.arrowDownToLine,
      );
    }
  }

  void _copyLink(BuildContext context, String url) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: url));
    TxSnackbar.show(
      context,
      'Media URL copied to clipboard',
      icon: LucideIcons.copy,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final snifferState = ref.watch(mediaSnifferProvider);
    final items = snifferState.items;
    final downloadableCount = snifferState.downloadableCount;
    final maxHeight = MediaQuery.of(context).size.height * 0.80;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TxSpacing.md,
          vertical: TxSpacing.sm,
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TxRadius.borderRadiusSheet,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: TxElevation.elevation3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              const SizedBox(height: TxSpacing.sm),
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
              const SizedBox(height: TxSpacing.sm),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.film,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: TxSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Media Sniffer',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.secondary.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${items.length} detected',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'High-speed 1-tap media extraction',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: colors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: TxSpacing.lg),

              // Media Items List
              Flexible(
                child: items.isEmpty
                    ? _buildEmptyState(context, colors)
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: TxSpacing.sm),
                        itemBuilder: (context, index) {
                          final media = items[index];
                          return _buildMediaCard(context, ref, colors, media);
                        },
                      ),
              ),

              // Bottom Bulk Action Bar
              if (downloadableCount > 1) ...[
                const Divider(height: TxSpacing.md),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TxSpacing.lg,
                    0,
                    TxSpacing.lg,
                    TxSpacing.md,
                  ),
                  child: TxButton(
                    label: 'Download All ($downloadableCount items)',
                    icon: LucideIcons.arrowDownToLine,
                    isFullWidth: true,
                    onPressed: () => _downloadAll(context, ref, items),
                  ),
                ),
              ] else ...[
                const SizedBox(height: TxSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TxColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(TxSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.film, size: 48, color: colors.textTertiary),
          const SizedBox(height: TxSpacing.md),
          Text(
            'No media resources detected yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Play a video or audio on the page to trigger detection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    WidgetRef ref,
    TxColorScheme colors,
    SniffedMedia media,
  ) {
    final extUpper = (media.mimeType.split('/').lastOrNull ?? 'MEDIA').toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.45),
        borderRadius: TxRadius.borderRadiusMd,
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(TxSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail / Icon
              _buildThumbnailOrIcon(colors, media),
              const SizedBox(width: TxSpacing.md),

              // Title and Host
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.fileName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.globe, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            media.sourceHost,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: TxSpacing.sm),

          // Chips Row: Extension, Resolution, Estimated Size
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(
                label: extUpper,
                color: colors.primary,
                bgColor: colors.primary.withValues(alpha: 0.1),
              ),
              if (media.resolution != null)
                _buildBadge(
                  label: media.resolution!,
                  color: colors.secondary,
                  bgColor: colors.secondary.withValues(alpha: 0.1),
                ),
              _buildBadge(
                label: media.formattedSize,
                color: colors.textSecondary,
                bgColor: colors.borderSubtle,
              ),
            ],
          ),

          const SizedBox(height: TxSpacing.sm),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyLink(context, media.url),
                icon: const Icon(LucideIcons.copy, size: 14),
                label: const Text('Copy Link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: TxRadius.borderRadiusSm,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.sm),
              TxButton(
                label: media.isStream ? 'Download Manifest' : 'Download',
                icon: LucideIcons.download,
                onPressed: () => _downloadItem(context, ref, media),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailOrIcon(TxColorScheme colors, SniffedMedia media) {
    if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: TxRadius.borderRadiusSm,
        child: Image.network(
          media.thumbnailUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackMediaIcon(colors, media),
        ),
      );
    }
    return _fallbackMediaIcon(colors, media);
  }

  Widget _fallbackMediaIcon(TxColorScheme colors, SniffedMedia media) {
    final iconData = media.isAudio
        ? LucideIcons.music
        : (media.isStream ? LucideIcons.radar : LucideIcons.film);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: colors.primary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
