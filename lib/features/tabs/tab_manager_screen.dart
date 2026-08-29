import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/cards/tab_card.dart';
import '../../widgets/ads/tx_native_ad_card.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';

enum TabFilterMode { regular, incognito, recentlyClosed }

/// Commercial-grade Spatial Tab Manager Screen for Tx Browser.
class TabManagerScreen extends ConsumerStatefulWidget {
  const TabManagerScreen({super.key});

  @override
  ConsumerState<TabManagerScreen> createState() => _TabManagerScreenState();
}

class _TabManagerScreenState extends ConsumerState<TabManagerScreen> {
  TabFilterMode _filterMode = TabFilterMode.regular;
  bool _isGridView = true;
  bool _isSearching = false;
  String? _selectedGroupId;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTabSelect(TabModel tab) {
    HapticFeedback.lightImpact();
    ref.read(tabsProvider.notifier).switchToTab(tab.id);
    if (tab.url.isNotEmpty) {
      context.go('/browser', extra: tab.url);
    } else {
      context.go('/');
    }
  }

  void _onTabClose(String id) {
    HapticFeedback.mediumImpact();
    ref.read(tabsProvider.notifier).closeTab(id);
  }

  void _openNewTab({bool isPrivate = false}) {
    HapticFeedback.lightImpact();
    ref.read(tabsProvider.notifier).openTab(isPrivate: isPrivate);
    context.go('/');
  }

  void _showTabContextMenu(BuildContext context, TabModel tab) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TxSpacing.lg,
            vertical: TxSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header preview
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (tab.isPrivate ? colors.privateAccent : colors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tab.isPrivate ? LucideIcons.shieldCheck : LucideIcons.layers,
                      size: 18,
                      color: tab.isPrivate ? colors.privateAccent : colors.primary,
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab.title.isNotEmpty ? tab.title : 'New Tab',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tab.url.isNotEmpty)
                          Text(
                            tab.url,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: TxSpacing.md),
              Divider(color: colors.borderSubtle, height: 1),
              const SizedBox(height: TxSpacing.xs),

              // Actions
              ListTile(
                leading: Icon(LucideIcons.externalLink, color: colors.textPrimary),
                title: const Text('Open Tab'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _onTabSelect(tab);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.copy, color: colors.textPrimary),
                title: const Text('Duplicate Tab'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).duplicateTab(tab.id);
                },
              ),
              if (tab.url.isNotEmpty) ...[
                ListTile(
                  leading: Icon(LucideIcons.clipboardCopy, color: colors.textPrimary),
                  title: const Text('Copy URL'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: tab.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(LucideIcons.share2, color: colors.textPrimary),
                  title: const Text('Share Link'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    SharePlus.instance.share(
                      ShareParams(
                        uri: Uri.tryParse(tab.url),
                      ),
                    );
                  },
                ),
              ],
              if (!tab.isPrivate)
                ListTile(
                  leading: Icon(LucideIcons.folderPlus, color: colors.primary),
                  title: const Text('Add to Tab Group'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAssignGroupPicker(context, tab);
                  },
                ),
              ListTile(
                leading: Icon(LucideIcons.layers2, color: colors.textPrimary),
                title: const Text('Close Other Tabs'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).closeOtherTabs(
                        tab.id,
                        isPrivate: tab.isPrivate,
                      );
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.error),
                title: Text(
                  'Close Tab',
                  style: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
                ),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _onTabClose(tab.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final titleCtrl = TextEditingController();
    var selectedColor = 0xFF609966;
    final colorOptions = [
      0xFF609966, // Emerald / Brand Green
      0xFF4A90E2, // Blue
      0xFFE67E22, // Orange
      0xFF9B59B6, // Purple
      0xFFE74C3C, // Red
      0xFF1ABC9C, // Teal
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + TxSpacing.lg,
            left: TxSpacing.lg,
            right: TxSpacing.lg,
            top: TxSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TxSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'New Tab Group',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: TxSpacing.md),
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. Work, Research, Social',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: TxRadius.borderRadiusSm,
                    borderSide: BorderSide(color: colors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: TxSpacing.md),
              Text(
                'Group Color',
                style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: TxSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colorOptions.map((c) {
                  final isSel = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSel
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: isSel ? TxElevation.elevation2 : null,
                      ),
                      child: isSel
                          ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: TxSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: TxRadius.borderRadiusSm),
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(color: colors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: TxButton(
                      label: 'Create Group',
                      onPressed: () {
                        if (titleCtrl.text.trim().isNotEmpty) {
                          ref.read(tabsProvider.notifier).createGroup(
                                title: titleCtrl.text.trim(),
                                colorValue: selectedColor,
                              );
                          Navigator.pop(ctx);
                        }
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

  void _showAssignGroupPicker(BuildContext context, TabModel tab) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final tabState = ref.read(tabsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TxSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TxSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Assign Tab to Group',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ListTile(
                leading: const Icon(LucideIcons.folderX),
                title: const Text('None (Remove from Group)'),
                trailing: tab.groupId == null
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(tabsProvider.notifier).assignTabToGroup(
                        tabId: tab.id,
                        groupId: null,
                      );
                  Navigator.pop(ctx);
                },
              ),
              ...tabState.groups.map((group) {
                final isCurrent = tab.groupId == group.id;
                return ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(group.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(group.title),
                  trailing: isCurrent
                      ? Icon(LucideIcons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    ref.read(tabsProvider.notifier).assignTabToGroup(
                          tabId: tab.id,
                          groupId: group.id,
                        );
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupOptionsSheet(BuildContext context, TabGroupModel group) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TxSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TxSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(group.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(LucideIcons.plus),
                title: const Text('Add New Tab in Group'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).newTab(groupId: group.id);
                  context.go('/');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.layers2),
                title: const Text('Close All Tabs in Group'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).closeGroupTabs(group.id);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.error),
                title: Text('Delete Group', style: TextStyle(color: colors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_selectedGroupId == group.id) {
                    setState(() => _selectedGroupId = null);
                  }
                  ref.read(tabsProvider.notifier).deleteGroup(group.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCloseAll(BuildContext context, bool isPrivate) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isPrivate ? 'Close All Private Tabs?' : 'Close All Tabs?',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isPrivate
              ? 'All private browsing session tabs will be securely closed and deleted.'
              : 'All open tabs will be closed and added to recently closed.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tabsProvider.notifier).closeAllTabs(isPrivate: isPrivate);
              ref.read(adServiceProvider).recordUserAction();
              ref.read(adServiceProvider).maybeShowInterstitial();
            },
            child: const Text('Close All'),
          ),
        ],
      ),
    );
  }

  void _confirmClearRecentlyClosed(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Recently Closed?',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will clear the recently closed tabs history permanently.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(recentlyClosedProvider.notifier).clearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final tabState = ref.watch(tabsProvider);
    final recentlyClosed = ref.watch(recentlyClosedProvider);

    final regularTabs = tabState.tabs.where((t) => !t.isPrivate).toList();
    final privateTabs = tabState.tabs.where((t) => t.isPrivate).toList();

    List<TabModel> currentTabs = _filterMode == TabFilterMode.incognito
        ? privateTabs
        : regularTabs;

    // Filter by selected Tab Group in regular mode
    if (_filterMode == TabFilterMode.regular && _selectedGroupId != null) {
      currentTabs = currentTabs.where((t) => t.groupId == _selectedGroupId).toList();
    }

    // Apply search filter if searching
    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty && _filterMode != TabFilterMode.recentlyClosed) {
      currentTabs = currentTabs.where((t) {
        return t.title.toLowerCase().contains(searchQuery) ||
            t.url.toLowerCase().contains(searchQuery);
      }).toList();
    }

    final filteredClosedTabs = searchQuery.isNotEmpty
        ? recentlyClosed.where((c) {
            return c.title.toLowerCase().contains(searchQuery) ||
                c.url.toLowerCase().contains(searchQuery);
          }).toList()
        : recentlyClosed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else if (tabState.activeTab != null &&
            tabState.activeTab!.url.isNotEmpty) {
          context.go(
            '/browser',
            extra: tabState.activeTab!.url,
          );
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: _filterMode == TabFilterMode.incognito
            ? (Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFE8EDE3)
                : colors.bg)
            : colors.bg,
        body: SafeArea(
          child: TxResponsiveContainer(
            maxWidth: 840,
            child: Column(
              children: [
                // ─── 1. TOP ACTION BAR ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TxSpacing.lg,
                    TxSpacing.sm,
                    TxSpacing.sm,
                    TxSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      // Header Title & Counter Badge
                      Row(
                        children: [
                          Text(
                            'Tabs',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                  fontSize: 24,
                                ),
                          ),
                          const SizedBox(width: TxSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tabState.count}',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Search Toggle Button
                      IconButton(
                        icon: Icon(
                          _isSearching ? LucideIcons.x : LucideIcons.search,
                          size: 20,
                          color: colors.textPrimary,
                        ),
                        tooltip: 'Search tabs',
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) _searchCtrl.clear();
                          });
                        },
                      ),

                      // Grid / List View Toggle Button
                      if (_filterMode != TabFilterMode.recentlyClosed)
                        IconButton(
                          icon: Icon(
                            _isGridView ? LucideIcons.list : LucideIcons.layoutGrid,
                            size: 20,
                            color: colors.textPrimary,
                          ),
                          tooltip: _isGridView ? 'List view' : 'Grid view',
                          onPressed: () {
                            setState(() => _isGridView = !_isGridView);
                          },
                        ),

                      // 3-Dots Overflow Menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          LucideIcons.ellipsisVertical,
                          color: colors.textPrimary,
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) {
                          if (value == 'close_all_regular') {
                            _confirmCloseAll(context, false);
                          } else if (value == 'close_all_private') {
                            _confirmCloseAll(context, true);
                          } else if (value == 'clear_recently_closed') {
                            _confirmClearRecentlyClosed(context);
                          } else if (value == 'new_tab') {
                            _openNewTab(isPrivate: false);
                          } else if (value == 'new_private') {
                            _openNewTab(isPrivate: true);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'new_tab',
                            child: Row(
                              children: [
                                Icon(LucideIcons.plus, size: 18),
                                SizedBox(width: 10),
                                Text('New Tab'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'new_private',
                            child: Row(
                              children: [
                                Icon(LucideIcons.shieldCheck, size: 18),
                                SizedBox(width: 10),
                                Text('New Private Tab'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          if (regularTabs.isNotEmpty)
                            const PopupMenuItem(
                              value: 'close_all_regular',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.trash2, size: 18),
                                  SizedBox(width: 10),
                                  Text('Close all regular tabs'),
                                ],
                              ),
                            ),
                          if (privateTabs.isNotEmpty)
                            const PopupMenuItem(
                              value: 'close_all_private',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.shieldAlert, size: 18),
                                  SizedBox(width: 10),
                                  Text('Close all private tabs'),
                                ],
                              ),
                            ),
                          if (recentlyClosed.isNotEmpty)
                            const PopupMenuItem(
                              value: 'clear_recently_closed',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.history, size: 18),
                                  SizedBox(width: 10),
                                  Text('Clear recently closed'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── 2. SEARCH INPUT (COLLAPSIBLE) ─────────────────
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TxSpacing.lg,
                      vertical: TxSpacing.xs,
                    ),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Filter open or closed tabs...',
                          hintStyle: TextStyle(
                            color: colors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 13.5,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  onPressed: () {
                                    setState(() => _searchCtrl.clear());
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),

                // ─── 3. 3-WAY FILTER SEGMENT CONTROL ───────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TxSpacing.lg,
                    vertical: TxSpacing.xs,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: TxRadius.borderRadiusFull,
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _SegmentTab(
                          label: 'Open (${regularTabs.length})',
                          icon: LucideIcons.layers,
                          isSelected: _filterMode == TabFilterMode.regular,
                          onTap: () => setState(
                              () => _filterMode = TabFilterMode.regular),
                          colors: colors,
                        ),
                        _SegmentTab(
                          label: 'Private (${privateTabs.length})',
                          icon: LucideIcons.shieldCheck,
                          isSelected: _filterMode == TabFilterMode.incognito,
                          onTap: () => setState(
                              () => _filterMode = TabFilterMode.incognito),
                          colors: colors,
                        ),
                        _SegmentTab(
                          label: 'Closed (${recentlyClosed.length})',
                          icon: LucideIcons.history,
                          isSelected: _filterMode == TabFilterMode.recentlyClosed,
                          onTap: () => setState(
                              () => _filterMode = TabFilterMode.recentlyClosed),
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab Groups Filter Row (Regular mode)
                if (_filterMode == TabFilterMode.regular)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TxSpacing.lg,
                      vertical: TxSpacing.xs,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Tabs'),
                            selected: _selectedGroupId == null,
                            onSelected: (_) => setState(() => _selectedGroupId = null),
                          ),
                          const SizedBox(width: 8),
                          ...tabState.groups.map((group) {
                            final isSel = _selectedGroupId == group.id;
                            final groupTabsCount = tabState.tabs.where((t) => t.groupId == group.id).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InputChip(
                                avatar: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(group.colorValue),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                label: Text('${group.title} ($groupTabsCount)'),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedGroupId = isSel ? null : group.id;
                                  });
                                },
                                onDeleted: () => _showGroupOptionsSheet(context, group),
                                deleteIcon: const Icon(LucideIcons.moreVertical, size: 14),
                              ),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(LucideIcons.plus, size: 14),
                            label: const Text('New Group'),
                            onPressed: () => _showCreateGroupDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: TxSpacing.xs),

                // ─── 4. TABS CONTENT VIEWPORT ──────────────────────
                Expanded(
                  child: _filterMode == TabFilterMode.recentlyClosed
                      // Recently Closed View
                      ? (filteredClosedTabs.isEmpty
                          ? _EmptyRecentlyClosedState(
                              hasHistory: recentlyClosed.isNotEmpty,
                              colors: colors,
                            )
                          : ListView.separated(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: TxSpacing.lg,
                                vertical: TxSpacing.sm,
                              ),
                              itemCount: filteredClosedTabs.length + 1,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: TxSpacing.sm),
                              itemBuilder: (context, index) {
                                if (index == filteredClosedTabs.length) {
                                  return const TxNativeAdCard(
                                    variant: TxAdSizeVariant.standardBanner,
                                    margin: EdgeInsets.only(top: TxSpacing.xs),
                                  );
                                }
                                final item = filteredClosedTabs[index];
                                return _RecentlyClosedTile(
                                  item: item,
                                  relativeTime:
                                      _formatRelativeTime(item.closedAt),
                                  onRestore: () {
                                    HapticFeedback.lightImpact();
                                    final restoredUrl = item.url;
                                    ref
                                        .read(tabsProvider.notifier)
                                        .restoreClosedTab(item);
                                    if (restoredUrl.isNotEmpty) {
                                      context.go(
                                        '/browser',
                                        extra: restoredUrl,
                                      );
                                    } else {
                                      context.go('/');
                                    }
                                  },
                                  onDelete: () {
                                    ref
                                        .read(recentlyClosedProvider.notifier)
                                        .removeTab(item.id);
                                  },
                                  colors: colors,
                                );
                              },
                            ))
                      // Open / Private Tabs View
                      : (currentTabs.isEmpty
                          ? _EmptyTabState(
                              isPrivate: _filterMode == TabFilterMode.incognito,
                              onNewTab: () => _openNewTab(
                                isPrivate:
                                    _filterMode == TabFilterMode.incognito,
                              ),
                            )
                          : (_isGridView
                              // Grid View Mode
                              ? GridView.builder(
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: TxSpacing.lg,
                                    vertical: TxSpacing.sm,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisSpacing: TxSpacing.md,
                                    crossAxisSpacing: TxSpacing.md,
                                    childAspectRatio: 0.80,
                                  ),
                                  itemCount: currentTabs.length,
                                  itemBuilder: (context, index) {
                                    final tab = currentTabs[index];
                                    return TabCard(
                                      key: ValueKey(tab.id),
                                      title: tab.title,
                                      url: tab.url,
                                      isActive: tab.id == tabState.activeTabId,
                                      faviconUrl: tab.faviconUrl,
                                      previewBytes: tab.previewBytes,
                                      isPrivate: tab.isPrivate,
                                      onTap: () => _onTabSelect(tab),
                                      onClose: () => _onTabClose(tab.id),
                                      onLongPress: () =>
                                          _showTabContextMenu(context, tab),
                                    );
                                  },
                                )
                              // List View / Reorderable Mode
                              : ReorderableListView.builder(
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: TxSpacing.lg,
                                    vertical: TxSpacing.sm,
                                  ),
                                  itemCount: currentTabs.length,
                                  // ignore: deprecated_member_use
                                  onReorder: (oldIndex, newIndex) {
                                    ref
                                        .read(tabsProvider.notifier)
                                        .reorderTabs(oldIndex, newIndex);
                                  },
                                  itemBuilder: (context, index) {
                                    final tab = currentTabs[index];
                                    return Padding(
                                      key: ValueKey(tab.id),
                                      padding: const EdgeInsets.only(
                                          bottom: TxSpacing.sm),
                                      child: Dismissible(
                                        key: Key('dismiss_${tab.id}'),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss: (direction) async {
                                          // Require deliberate full swipe to prevent accidental closures during scroll
                                          return true;
                                        },
                                        dismissThresholds: const {
                                          DismissDirection.endToStart: 0.45,
                                        },
                                        onDismissed: (_) => _onTabClose(tab.id),
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                              right: TxSpacing.lg),
                                          decoration: BoxDecoration(
                                            color: colors.error,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: const Icon(
                                            LucideIcons.trash2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        child: TabListTile(
                                          title: tab.title,
                                          url: tab.url,
                                          isActive:
                                              tab.id == tabState.activeTabId,
                                          faviconUrl: tab.faviconUrl,
                                          previewBytes: tab.previewBytes,
                                          isPrivate: tab.isPrivate,
                                          onTap: () => _onTabSelect(tab),
                                          onClose: () => _onTabClose(tab.id),
                                          onLongPress: () =>
                                              _showTabContextMenu(context, tab),
                                        ),
                                      ),
                                    );
                                  },
                                ))),
                ),
              ],
            ),
          ),
        ),

        // ─── 5. GROUNDED DOCKED BOTTOM ACTION BAR WITH IN-FEED AD ───
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TxNativeAdCard(
                variant: TxAdSizeVariant.standardBanner,
                margin: EdgeInsets.symmetric(horizontal: TxSpacing.lg, vertical: 4),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  TxSpacing.lg,
                  TxSpacing.xs,
                  TxSpacing.lg,
                  TxSpacing.md,
                ),
                child: Center(
                  heightFactor: 1.0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Row(
                      children: [
                        Expanded(
                          child: TxButton(
                            label: _filterMode == TabFilterMode.incognito
                                ? 'New Private Tab'
                                : 'New Tab',
                            icon: LucideIcons.plus,
                            variant: TxButtonVariant.primary,
                            onPressed: () => _openNewTab(
                              isPrivate: _filterMode == TabFilterMode.incognito,
                            ),
                          ),
                        ),
                        const SizedBox(width: TxSpacing.md),
                        TxButton(
                          label: 'Done',
                          variant: TxButtonVariant.secondary,
                          onPressed: () {
                            if (tabState.activeTab != null &&
                                tabState.activeTab!.url.isNotEmpty) {
                              context.go(
                                '/browser',
                                extra: tabState.activeTab!.url,
                              );
                            } else {
                              context.go('/');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting Tab Manager Components
// ---------------------------------------------------------------------------

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TxPressable(
        onTap: onTap,
        scaleDown: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: TxRadius.borderRadiusFull,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected ? Colors.white : colors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11.5,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({
    required this.isPrivate,
    required this.onNewTab,
  });

  final bool isPrivate;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: (isPrivate ? colors.privateAccent : colors.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPrivate ? LucideIcons.shieldCheck : LucideIcons.layers,
                size: 36,
                color: isPrivate ? colors.privateAccent : colors.primary,
              ),
            ),
            const SizedBox(height: TxSpacing.lg),
            Text(
              isPrivate ? 'No Private Tabs' : 'No Open Tabs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: TxSpacing.xs),
            Text(
              isPrivate
                  ? 'Private tabs do not save history, cookies, or cache upon closing.'
                  : 'Start browsing the web with a new tab.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TxSpacing.lg),
            TxButton(
              label: isPrivate ? 'Open Private Tab' : 'Open New Tab',
              icon: LucideIcons.plus,
              onPressed: onNewTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecentlyClosedState extends StatelessWidget {
  const _EmptyRecentlyClosedState({
    required this.hasHistory,
    required this.colors,
  });

  final bool hasHistory;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
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
              hasHistory ? 'No Matching Closed Tabs' : 'No Recently Closed Tabs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: TxSpacing.xs),
            Text(
              hasHistory
                  ? 'Try a different search query.'
                  : 'Tabs you close during your browsing session will appear here for easy 1-tap restoration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentlyClosedTile extends StatelessWidget {
  const _RecentlyClosedTile({
    required this.item,
    required this.relativeTime,
    required this.onRestore,
    required this.onDelete,
    required this.colors,
  });

  final RecentlyClosedTab item;
  final String relativeTime;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final TxColorScheme colors;

  String _cleanHost(String url) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _cleanHost(item.url);

    return TxPressable(
      onTap: onRestore,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: TxElevation.elevation1,
        ),
        child: Row(
          children: [
            // Closed Favicon / History Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: (item.faviconUrl != null && item.faviconUrl!.isNotEmpty)
                    ? Image.network(
                        item.faviconUrl!,
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          LucideIcons.globe,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      )
                    : Icon(
                        LucideIcons.globe,
                        size: 18,
                        color: colors.textSecondary,
                      ),
              ),
            ),

            const SizedBox(width: TxSpacing.md),

            // Title, Host and Relative Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          host,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: colors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        relativeTime,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 11.5,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 1-Tap Restore Button
            TxPressable(
              onTap: onRestore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.rotateCcw,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Restore',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
