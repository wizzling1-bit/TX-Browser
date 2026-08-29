import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../services/download_service/download_service.dart';
import '../../state/downloads_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/ads/tx_native_ad_card.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';

/// Commercial-grade Downloads screen with active progress, file opening, sharing, and deletion.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
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

IconData _getMimeIcon(String mimeType) {
  if (mimeType.startsWith('image/')) return LucideIcons.image;
  if (mimeType.startsWith('video/')) return LucideIcons.film;
  if (mimeType.startsWith('audio/')) return LucideIcons.music;
  if (mimeType.contains('pdf')) return LucideIcons.fileText;
  if (mimeType.contains('zip') || mimeType.contains('tar') || mimeType.contains('rar')) {
    return LucideIcons.folderArchive;
  }
  if (mimeType.contains('apk')) return LucideIcons.box;
  return LucideIcons.file;
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(downloadsProvider.notifier).loadDownloads();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final downloads = ref.watch(downloadsProvider);
    final active = downloads
        .where((d) => d.status == DownloadStatus.downloading)
        .toList();
    final completed = downloads
        .where((d) => d.status == DownloadStatus.completed)
        .toList();
    final failed = downloads
        .where((d) =>
            d.status == DownloadStatus.failed ||
            d.status == DownloadStatus.cancelled)
        .toList();

    final hasDownloads =
        active.isNotEmpty || completed.isNotEmpty || failed.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
        leading: TxIconButton(
          icon: LucideIcons.chevronLeft,
          semanticLabel: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Downloads'),
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 720,
          child: !hasDownloads
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.download,
                          size: 32,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: TxSpacing.md),
                      Text(
                        'No Downloads Yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Downloaded files and documents will appear here.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(TxSpacing.lg),
                  children: [
                    // Active Downloads
                    if (active.isNotEmpty) ...[
                      _SectionHeader(title: 'Active Downloads (${active.length})', colors: colors),
                      const SizedBox(height: TxSpacing.xs),
                      ...active.map((item) => _ActiveDownloadCard(
                            item: item,
                            onCancel: () => ref.read(downloadsProvider.notifier).cancelDownload(item.id),
                            colors: colors,
                          )),
                      const SizedBox(height: TxSpacing.lg),
                    ],

                    // Completed Downloads
                    if (completed.isNotEmpty) ...[
                      _SectionHeader(title: 'Completed (${completed.length})', colors: colors),
                      const SizedBox(height: TxSpacing.xs),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: TxRadius.borderRadiusMd,
                          border: Border.all(color: colors.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < completed.length; i++) ...[
                              _CompletedDownloadRow(
                                item: completed[i],
                                formattedSize: _formatBytes(completed[i].sizeBytes),
                                icon: _getMimeIcon(completed[i].mimeType),
                                onOpen: () {
                                  ref.read(adServiceProvider).recordUserAction();
                                  ref.read(downloadsProvider.notifier).openDownload(completed[i].id);
                                },
                                onShare: () {
                                  if (completed[i].filePath.isNotEmpty) {
                                    SharePlus.instance.share(
                                      ShareParams(uri: Uri.file(completed[i].filePath)),
                                    );
                                  }
                                },
                                onDelete: () => ref.read(downloadsProvider.notifier).deleteDownload(completed[i].id),
                                colors: colors,
                              ),
                              if (i < completed.length - 1)
                                Divider(color: colors.borderSubtle, height: 1, indent: 56),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: TxSpacing.md),
                      const TxNativeAdCard(margin: EdgeInsets.zero),
                      const SizedBox(height: TxSpacing.lg),
                    ],

                    // Failed / Cancelled
                    if (failed.isNotEmpty) ...[
                      _SectionHeader(title: 'Failed or Cancelled', colors: colors),
                      const SizedBox(height: TxSpacing.xs),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: TxRadius.borderRadiusMd,
                          border: Border.all(color: colors.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < failed.length; i++) ...[
                              _FailedDownloadRow(
                                item: failed[i],
                                onRetry: () => ref.read(downloadsProvider.notifier).startDownload(failed[i].sourceUrl, customFileName: failed[i].fileName),
                                onDelete: () => ref.read(downloadsProvider.notifier).deleteDownload(failed[i].id),
                                colors: colors,
                              ),
                              if (i < failed.length - 1)
                                Divider(color: colors.borderSubtle, height: 1, indent: 56),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
          ),
        ),
      ),
    ),
  );
}
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colors});

  final String title;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  const _ActiveDownloadCard({
    required this.item,
    required this.onCancel,
    required this.colors,
  });

  final DownloadModel item;
  final VoidCallback onCancel;
  final TxColorScheme colors;

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    return '${_formatBytes(bytesPerSec)}/s';
  }

  @override
  Widget build(BuildContext context) {
    final downloadedStr = _formatBytes(item.downloadedBytes);
    final totalStr = item.sizeBytes > 0 ? _formatBytes(item.sizeBytes) : 'Unknown';
    final speedStr = _formatSpeed(item.speedBytesPerSec);

    return Container(
      margin: const EdgeInsets.only(bottom: TxSpacing.sm),
      padding: const EdgeInsets.all(TxSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusMd,
        border: Border.all(color: colors.primary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: TxElevation.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.arrowDownToLine, size: 18, color: colors.primary),
              ),
              const SizedBox(width: TxSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$downloadedStr / $totalStr ${speedStr.isNotEmpty ? "• $speedStr" : ""}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TxSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.progressPercent}%',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.xs),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                tooltip: 'Cancel download',
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: TxSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progressPercent > 0 ? item.progressPercent / 100.0 : null,
              backgroundColor: colors.border,
              color: colors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedDownloadRow extends StatelessWidget {
  const _CompletedDownloadRow({
    required this.item,
    required this.formattedSize,
    required this.icon,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
    required this.colors,
  });

  final DownloadModel item;
  final String formattedSize;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return TxPressable(
      onTap: onOpen,
      scaleDown: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: colors.primary),
              ),
            ),
            const SizedBox(width: TxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedSize,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.share2, size: 18, color: colors.textSecondary),
              onPressed: onShare,
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: colors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedDownloadRow extends StatelessWidget {
  const _FailedDownloadRow({
    required this.item,
    required this.onRetry,
    required this.onDelete,
    required this.colors,
  });

  final DownloadModel item;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(LucideIcons.alertCircle, size: 18, color: colors.error),
            ),
          ),
          const SizedBox(width: TxSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: TextStyle(fontWeight: FontWeight.w500, color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Failed to complete',
                  style: TextStyle(fontSize: 12, color: colors.error),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.rotateCw, size: 18, color: colors.primary),
            onPressed: onRetry,
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 18, color: colors.textSecondary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
