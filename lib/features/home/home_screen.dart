import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../state/shortcuts_provider.dart';
import '../../state/history_provider.dart';
import '../../state/tabs_provider.dart';
import '../../state/settings_provider.dart';
import '../../services/search_service/search_service.dart';
import '../../services/voice_service/voice_search_sheet.dart';
import '../exit/exit_dialog.dart';
import '../../widgets/browser/shield_dashboard_sheet.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/brand_icons.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/ads/tx_native_ad_card.dart';
import '../../services/ad_service/ad_service.dart';
import '../../services/suggestion_service/suggestion_model.dart';
import '../../state/suggestions_provider.dart';
import '../../widgets/search/search_suggestions_panel.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// Home screen — pixel-perfect implementation of Home.png design.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchService = const SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<HistoryEntryModel> _recentEntries = [];
  bool _showPrivacyBanner = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchQueryChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadData();
  }

  void _onSearchQueryChanged() {
    ref.read(suggestionsProvider.notifier).onQueryChanged(_searchController.text);
    if (mounted) setState(() {});
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
      ref.read(suggestionsProvider.notifier).onQueryChanged(_searchController.text);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(shortcutsProvider.notifier).loadShortcuts();
    final entries =
        await ref.read(historyProvider.notifier).getRecent(limit: 6);
    if (mounted) {
      setState(() => _recentEntries = entries);
    }
  }

  void _onSearchTap() {
    _searchFocusNode.requestFocus();
  }

  void _onMicTap() {
    VoiceSearchSheet.show(
      context,
      onResult: (text) {
        if (text.trim().isNotEmpty) {
          _searchController.text = text;
          _performSearch(text.trim());
        }
      },
    );
  }

  void _onQrTap() {
    ref.read(adServiceProvider).recordUserAction();
    context.push('/scanner');
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    _searchFocusNode.unfocus();
    ref.read(suggestionsProvider.notifier).clear();
    ref.read(adServiceProvider).recordUserAction();
    final engine = ref.read(settingsProvider).searchEngine;
    final resolved = _searchService.resolve(query, engine: engine);
    ref.read(tabsProvider.notifier).openTab(url: resolved);
    context.go('/browser', extra: resolved);
  }

  void _onSelectSuggestion(SearchSuggestion suggestion) {
    _searchFocusNode.unfocus();
    ref.read(suggestionsProvider.notifier).clear();
    ref.read(adServiceProvider).recordUserAction();
    ref.read(tabsProvider.notifier).openTab(url: suggestion.url);
    context.go('/browser', extra: suggestion.url);
  }

  void _onShortcutTap(ShortcutModel shortcut) {
    ref.read(adServiceProvider).recordUserAction();
    ref.read(tabsProvider.notifier).openTab(url: shortcut.url);
    context.go('/browser', extra: shortcut.url);
  }

  void _onRecentTap(HistoryEntryModel entry) {
    ref.read(adServiceProvider).recordUserAction();
    ref.read(tabsProvider.notifier).openTab(url: entry.url);
    context.go('/browser', extra: entry.url);
  }

  void _onAddShortcut() {
    _showAddShortcutSheet(context);
  }

  void _showAddShortcutSheet(BuildContext context) {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + TxSpacing.lg,
          left: TxSpacing.lg,
          right: TxSpacing.lg,
          top: TxSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to Quick Access',
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Notion',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'Web Address (URL)',
                hintText: 'https://notion.so',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: TxSpacing.lg),
            TxButton(
              label: 'Add Shortcut',
              isFullWidth: true,
              onPressed: () {
                if (labelCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  ref.read(shortcutsProvider.notifier).addShortcut(
                        label: labelCtrl.text,
                        url: urlCtrl.text,
                      );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyInfoSheet(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TxSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 24,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'On-Device Privacy',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Zero cloud tracking. On-device local privacy.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TxSpacing.lg),
              Text(
                'TX Browser operates locally on your device. Your browsing history, cookies, and tabs never leave your phone. No telemetry, no third-party behavioral tracking, and private tabs purge automatically upon exit.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: TxSpacing.xl),
              TxButton(
                label: 'Got It',
                isFullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHomeQuickMenu(BuildContext context, Offset globalPos) async {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPos.dx - 10, globalPos.dy + 15, 20, 20),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colors.border.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      items: [
        _buildPopupItem('new_tab', LucideIcons.plus, 'New tab', colors),
        _buildPopupItem('new_private_tab', LucideIcons.shieldCheck, 'New private tab', colors),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('bookmarks', LucideIcons.bookmark, 'Bookmarks', colors),
        _buildPopupItem('history', LucideIcons.history, 'History', colors),
        _buildPopupItem('downloads', LucideIcons.download, 'Downloads', colors),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('shield', LucideIcons.shieldAlert, 'TX Shield & Privacy', colors),
        _buildPopupItem('settings', LucideIcons.settings, 'Settings', colors),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('exit', LucideIcons.power, 'Exit TX Browser', colors, isDestructive: true),
      ],
    );

    if (selected == null || !mounted) return;
    _handleQuickAction(selected);
  }

  void _showHomeMenuSheet(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: TxSpacing.sm),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: TxSpacing.md),
              _HomeMenuRow(
                icon: LucideIcons.plus,
                label: 'New tab',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('new_tab');
                },
              ),
              _HomeMenuRow(
                icon: LucideIcons.shieldCheck,
                label: 'New private tab',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('new_private_tab');
                },
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _HomeMenuRow(
                icon: LucideIcons.bookmark,
                label: 'Bookmarks',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('bookmarks');
                },
              ),
              _HomeMenuRow(
                icon: LucideIcons.history,
                label: 'History',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('history');
                },
              ),
              _HomeMenuRow(
                icon: LucideIcons.download,
                label: 'Downloads',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('downloads');
                },
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _HomeMenuRow(
                icon: LucideIcons.shieldAlert,
                label: 'TX Shield & Privacy',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('shield');
                },
              ),
              _HomeMenuRow(
                icon: LucideIcons.settings,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('settings');
                },
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _HomeMenuRow(
                icon: LucideIcons.power,
                label: 'Exit TX Browser',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _handleQuickAction('exit');
                },
              ),
              const SizedBox(height: TxSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'new_tab':
        ref.read(tabsProvider.notifier).openTab();
        break;
      case 'new_private_tab':
        ref.read(tabsProvider.notifier).openTab(isPrivate: true);
        break;
      case 'bookmarks':
        context.push('/bookmarks');
        break;
      case 'history':
        context.push('/history');
        break;
      case 'downloads':
        context.push('/downloads');
        break;
      case 'shield':
        showTxShieldDashboard(context, '');
        break;
      case 'settings':
        context.push('/settings');
        break;
      case 'exit':
        showTxExitDialog(context, ref);
        break;
    }
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String label,
    TxColorScheme colors, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDestructive ? colors.error : colors.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDestructive ? colors.error : colors.textPrimary,
                fontSize: 14,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyProvider, (prev, next) => _loadData());
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final shortcuts = ref.watch(shortcutsProvider);
    final tabCount = ref.watch(tabsProvider).count;

    final suggestionsState = ref.watch(suggestionsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          ref.read(suggestionsProvider.notifier).clear();
        } else {
          showTxExitDialog(context, ref);
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.bg,
                colors.bg.withValues(alpha: 0.95),
                colors.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: TxResponsiveContainer(
              maxWidth: 720,
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.sm),
                  ),

                  // ─── 1. TOP BAR ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TxSpacing.lg,
                        vertical: TxSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Brandmark + Title + Tagline
                          Row(
                            children: [
                              // Green Leaf icon container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.85),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(22),
                                    topRight: Radius.circular(22),
                                    bottomLeft: Radius.circular(6),
                                    bottomRight: Radius.circular(22),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.leaf,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: TxSpacing.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TX Browser',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                          letterSpacing: -0.3,
                                          fontSize: 18,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Premium. Private. Powerful.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Right: Shield + 3-dots top buttons
                          Row(
                            children: [
                              _TopIconButton(
                                icon: LucideIcons.shieldCheck,
                                onTap: () => _showPrivacyInfoSheet(context),
                                colors: colors,
                              ),
                              const SizedBox(width: TxSpacing.sm),
                              _TopIconButton(
                                icon: LucideIcons.ellipsisVertical,
                                onTapDown: (details) =>
                                    _showHomeQuickMenu(context, details.globalPosition),
                                colors: colors,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.md),
                  ),

                  // ─── 2. SEARCH BAR & AUTOCOMPLETE PANEL ─────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _searchFocusNode.hasFocus
                                    ? colors.primary
                                    : colors.border,
                                width: _searchFocusNode.hasFocus ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: _searchFocusNode.hasFocus
                                          ? 0.08
                                          : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(
                                  LucideIcons.search,
                                  size: 20,
                                  color: _searchFocusNode.hasFocus
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search or type URL',
                                      hintStyle: TextStyle(
                                        color: colors.textSecondary
                                            .withValues(alpha: 0.7),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    textInputAction: TextInputAction.go,
                                    onSubmitted: (val) {
                                      if (val.trim().isNotEmpty) {
                                        _performSearch(val.trim());
                                      }
                                    },
                                  ),
                                ),
                                // Clear X button when text is present
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.x,
                                      size: 18,
                                      color: colors.textSecondary,
                                    ),
                                    tooltip: 'Clear text',
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(suggestionsProvider.notifier)
                                          .clear();
                                    },
                                  ),
                                // QR Scan Button
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.scanLine,
                                    size: 20,
                                    color: colors.textSecondary,
                                  ),
                                  tooltip: 'Scan QR code',
                                  onPressed: _onQrTap,
                                ),
                                // Circular Green Mic Button
                                TxPressable(
                                  onTap: _onMicTap,
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        LucideIcons.mic,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Autocomplete suggestions dropdown
                          if (_searchFocusNode.hasFocus &&
                              _searchController.text.trim().isNotEmpty &&
                              suggestionsState.suggestions.isNotEmpty)
                            SearchSuggestionsPanel(
                              suggestions: suggestionsState.suggestions,
                              isLoading: suggestionsState.isLoading,
                              onSelect: _onSelectSuggestion,
                              onInsert: (text) {
                                _searchController.text = text;
                                _searchController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: text.length),
                                );
                                ref
                                    .read(suggestionsProvider.notifier)
                                    .onQueryChanged(text);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.lg),
                  ),

                  // ─── 3. QUICK ACCESS BENTO GRID ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quick Access',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                ),
                          ),
                          TxPressable(
                            onTap: () => context.push('/pinned-sites'),
                            child: Text(
                              'Edit',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.sm),
                  ),

                  // Quick Access Bento Card (4x2 grid)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TxSpacing.sm,
                          vertical: TxSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: TxElevation.elevation1,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 520 ? 6 : 4;
                            final maxItems = crossAxisCount * 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: TxSpacing.md,
                                crossAxisSpacing: TxSpacing.xs,
                                childAspectRatio: constraints.maxWidth > 520 ? 0.90 : 0.84,
                              ),
                              itemCount: (shortcuts.length + 1).clamp(0, maxItems),
                              itemBuilder: (context, index) {
                                if (index < shortcuts.length && index < maxItems - 1) {
                                  final shortcut = shortcuts[index];
                                  return _QuickAccessItem(
                                    label: shortcut.label,
                                    onTap: () => _onShortcutTap(shortcut),
                                  );
                                } else {
                                  return _AddQuickAccessItem(
                                    onTap: _onAddShortcut,
                                    colors: colors,
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.lg),
                  ),

                  // ─── 4. PRIVACY FEATURE BANNER CARD ──────────────────
                  if (_showPrivacyBanner)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.lg),
                        child: Container(
                          padding: const EdgeInsets.all(TxSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: TxElevation.elevation1,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Abstract Art Illustration
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colors.primary,
                                      colors.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      top: -10,
                                      left: -10,
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          LucideIcons.shieldCheck,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: TxSpacing.md),

                              // Middle: Text & Learn more action
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Explore the web privately',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                            fontSize: 14.5,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'No tracking. No logging.\nJust you and the open web.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 11.5,
                                            height: 1.3,
                                          ),
                                    ),
                                    const SizedBox(height: TxSpacing.sm),
                                    TxPressable(
                                      onTap: () =>
                                          _showPrivacyInfoSheet(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Learn more',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right: Dismiss X Button
                              TxPressable(
                                onTap: () {
                                  setState(() => _showPrivacyBanner = false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_showPrivacyBanner)
                    const SliverToBoxAdapter(
                      child: SizedBox(height: TxSpacing.md),
                    ),

                  // ─── 4. NATIVE SPONSORED CARD ────────────────────────
                  const SliverToBoxAdapter(
                    child: TxNativeAdCard(),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.md),
                  ),

                  // ─── 5. RECENT SITES SECTION ─────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Sites',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                ),
                          ),
                          TxPressable(
                            onTap: () => context.push('/history'),
                            child: Row(
                              children: [
                                Text(
                                  'Show all',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 14,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.sm),
                  ),

                  // Recent Sites List Container
                  if (_recentEntries.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.lg),
                        child: Container(
                          padding: const EdgeInsets.all(TxSpacing.xl),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  LucideIcons.history,
                                  size: 28,
                                  color: colors.textTertiary,
                                ),
                                const SizedBox(height: TxSpacing.xs),
                                Text(
                                  'No recent browsing history',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.lg),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: TxElevation.elevation1,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < _recentEntries.length;
                                    i++) ...[
                                  _RecentSiteRow(
                                    entry: _recentEntries[i],
                                    onTap: () =>
                                        _onRecentTap(_recentEntries[i]),
                                    colors: colors,
                                  ),
                                  if (i < _recentEntries.length - 1)
                                    Divider(
                                      color: colors.borderSubtle,
                                      height: 1,
                                      indent: 56,
                                      endIndent: TxSpacing.md,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ─── 6. AD BANNER ───────────────────────────────────
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.md),
                  ),
                  const SliverToBoxAdapter(
                    child: AdBannerWidget(),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TxSpacing.md),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              TxSpacing.lg,
              0,
              TxSpacing.lg,
              8,
            ),
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _HomeBottomBar(
                  tabCount: tabCount,
                  onSearch: _onSearchTap,
                  onTabs: () => context.go('/tabs'),
                  onMenu: () => _showHomeMenuSheet(context),
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting UI Components (Matching Home.png)
// ---------------------------------------------------------------------------

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    this.onTap,
    this.onTapDown,
    required this.colors,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      child: TxPressable(
        onTap: onTap,
        scaleDown: 0.90,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return TxPressable(
      onTap: onTap,
      scaleDown: 0.92,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandIconBadge(
            name: label,
            size: 50,
            borderRadius: 15,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AddQuickAccessItem extends StatelessWidget {
  const _AddQuickAccessItem({
    required this.onTap,
    required this.colors,
  });

  final VoidCallback onTap;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return TxPressable(
      onTap: onTap,
      scaleDown: 0.92,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Icon(
              LucideIcons.plus,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentSiteRow extends StatelessWidget {
  const _RecentSiteRow({
    required this.entry,
    required this.onTap,
    required this.colors,
  });

  final HistoryEntryModel entry;
  final VoidCallback onTap;
  final TxColorScheme colors;

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 59)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

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
    return TxPressable(
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
              size: 40,
              borderRadius: 12,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cleanHost(entry.url),
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
            Text(
              _formatAgo(entry.visitedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11.5,
                  ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 16,
                color: colors.textSecondary.withValues(alpha: 0.8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 150),
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border),
              ),
              onSelected: (value) {
                if (value == 'open') {
                  onTap();
                } else if (value == 'copy') {
                  Clipboard.setData(ClipboardData(text: entry.url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(LucideIcons.externalLink, size: 16, color: colors.textPrimary),
                      const SizedBox(width: 8),
                      Text('Open', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(LucideIcons.clipboardCopy, size: 16, color: colors.textPrimary),
                      const SizedBox(width: 8),
                      Text('Copy Link', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.tabCount,
    required this.onSearch,
    required this.onTabs,
    required this.onMenu,
    required this.colors,
  });

  final int tabCount;
  final VoidCallback onSearch;
  final VoidCallback onTabs;
  final VoidCallback onMenu;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(33),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Home (Active pill)
          Expanded(
            child: TxPressable(
              onTap: () {},
              scaleDown: 0.90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.home,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Home',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Tabs
          Expanded(
            child: TxPressable(
              onTap: onTabs,
              scaleDown: 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        LucideIcons.layers,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            tabCount > 9 ? '9+' : tabCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tabs',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Center Search FAB
          TxPressable(
            onTap: onSearch,
            scaleDown: 0.90,
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.search,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 4. Downloads
          Expanded(
            child: TxPressable(
              onTap: () => context.push('/downloads'),
              scaleDown: 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.download,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Downloads',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Menu
          Expanded(
            child: TxPressable(
              onTap: onMenu,
              scaleDown: 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.menu,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Menu',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMenuRow extends StatelessWidget {
  const _HomeMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? colors.error.withValues(alpha: 0.1)
              : colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive ? colors.error : colors.primary,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? colors.error : colors.textPrimary,
          fontSize: 15,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
