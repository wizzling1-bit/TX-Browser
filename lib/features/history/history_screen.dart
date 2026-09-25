import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../state/history_provider.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/brand_icons.dart';
import '../../widgets/ads/tx_native_ad_card.dart';
import '../../widgets/dialogs/cache_cleaned_dialog.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';

/// Commercial-grade History screen with date groupings, search, and range clearing.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ref.read(historyProvider.notifier).loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onEntryTap(HistoryEntryModel entry) {
    ref.read(adServiceProvider).recordUserAction();
    ref.read(tabsProvider.notifier).openTab(url: entry.url);
    context.go('/browser', extra: entry.url);
  }

  void _showClearHistoryDialog(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TxSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Clear Browsing History',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.xs),
              Text(
                'Select the timeframe to purge from local storage.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: TxSpacing.md),
              _ClearOptionTile(
                title: 'Last hour',
                onTap: () {
                  ref.read(historyProvider.notifier).clearHistoryByRange('last_hour');
                  Navigator.pop(ctx);
                  ref.read(adServiceProvider).recordUserAction();
                },
                colors: colors,
              ),
              _ClearOptionTile(
                title: 'Today',
                onTap: () {
                  ref.read(historyProvider.notifier).clearHistoryByRange('today');
                  Navigator.pop(ctx);
                  ref.read(adServiceProvider).recordUserAction();
                },
                colors: colors,
              ),
              _ClearOptionTile(
                title: 'All time',
                isDestructive: true,
                onTap: () {
                  ref.read(historyProvider.notifier).clearHistoryByRange('all_time');
                  Navigator.pop(ctx);
                  ref.read(adServiceProvider).recordUserAction();
                  CacheCleanedDialog.show(context);
                },
                colors: colors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final historyNotifier = ref.read(historyProvider.notifier);
    ref.watch(historyProvider); // trigger rebuild on state change
    final groups = historyNotifier.getGroupedHistory(_searchQuery);

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
        title: const Text('History'),
        actions: [
          if (groups.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 20, color: colors.error),
              tooltip: 'Clear History',
              onPressed: () => _showClearHistoryDialog(context),
            ),
        ],
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 720,
          child: Column(
            children: [
              // Search filter bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TxSpacing.lg,
                  vertical: TxSpacing.xs,
                ),
                child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: TxRadius.borderRadiusSm,
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search history...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textTertiary,
                        ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: TxSpacing.xs),

            // History list or empty state
            Expanded(
              child: groups.isEmpty
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
                              LucideIcons.history,
                              size: 32,
                              color: colors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: TxSpacing.md),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching history'
                                : 'No browsing history',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Sites you visit in regular tabs will appear here.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TxSpacing.lg,
                        vertical: TxSpacing.sm,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, gIndex) {
                        final group = groups[gIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: TxSpacing.sm,
                                horizontal: 4,
                              ),
                              child: Text(
                                group.title.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: TxRadius.borderRadiusMd,
                                border: Border.all(
                                  color: colors.border,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0;
                                      i < group.entries.length;
                                      i++) ...[
                                    _HistoryRow(
                                      entry: group.entries[i],
                                      onTap: () =>
                                          _onEntryTap(group.entries[i]),
                                      onDelete: () {
                                        ref
                                            .read(historyProvider.notifier)
                                            .deleteEntry(group.entries[i].id);
                                      },
                                      colors: colors,
                                    ),
                                    if (i < group.entries.length - 1)
                                      Divider(
                                        color: colors.borderSubtle,
                                        height: 1,
                                        indent: 56,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            if (gIndex == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: TxSpacing.md),
                                child: TxNativeAdCard(
                                  margin: EdgeInsets.zero,
                                ),
                              ),
                            const SizedBox(height: TxSpacing.md),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.colors,
  });

  final HistoryEntryModel entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: TxSpacing.lg),
        color: colors.error.withValues(alpha: 0.15),
        child: Icon(LucideIcons.trash2, color: colors.error, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: TxPressable(
        onTap: onTap,
        scaleDown: 0.98,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TxSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              BrandIconBadge(
                name: entry.title,
                size: 36,
                borderRadius: 10,
              ),
              const SizedBox(width: TxSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.domain,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TxSpacing.sm),
              Text(
                entry.formattedTime,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textTertiary,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearOptionTile extends StatelessWidget {
  const _ClearOptionTile({
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    required this.colors,
  });

  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? colors.error : colors.textPrimary,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: colors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}
