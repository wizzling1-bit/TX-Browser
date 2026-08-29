import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/bookmarks_provider.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/ads/tx_native_ad_card.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';

/// Commercial-grade Bookmarks management screen with folder support, search, and refined native mobile sheets.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String? _currentFolderId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBookmark(BookmarkModel bookmark) {
    HapticFeedback.lightImpact();
    ref.read(adServiceProvider).recordUserAction();
    ref.read(tabsProvider.notifier).openUrl(bookmark.url);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/browser');
    }
  }

  void _showAddBookmarkDialog() {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? selectedFolderId = _currentFolderId;
    final folders = ref.read(bookmarksProvider).folders;

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
              // Top Drag Handle
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
                'Add Bookmark',
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
                  labelText: 'Title',
                  hintText: 'e.g. Flutter Documentation',
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
              const SizedBox(height: TxSpacing.sm),
              TextField(
                controller: urlCtrl,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://flutter.dev',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: TxRadius.borderRadiusSm,
                    borderSide: BorderSide(color: colors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
              ),
              if (folders.isNotEmpty) ...[
                const SizedBox(height: TxSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: selectedFolderId,
                  decoration: InputDecoration(
                    labelText: 'Folder',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: TxRadius.borderRadiusSm,
                      borderSide: BorderSide(color: colors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                  dropdownColor: colors.surface,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Bookmarks (Root)'),
                    ),
                    ...folders.map(
                      (f) => DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(f.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setSheetState(() => selectedFolderId = val),
                ),
              ],
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
                      label: 'Save Bookmark',
                      onPressed: () {
                        if (urlCtrl.text.trim().isNotEmpty) {
                          ref.read(bookmarksProvider.notifier).addBookmark(
                                title: titleCtrl.text.trim().isNotEmpty
                                    ? titleCtrl.text.trim()
                                    : urlCtrl.text.trim(),
                                url: urlCtrl.text.trim(),
                                folderId: selectedFolderId,
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

  void _showCreateFolderDialog() {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'New Bookmark Folder',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
              decoration: InputDecoration(
                labelText: 'Folder Name',
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
                    label: 'Create Folder',
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        ref.read(bookmarksProvider.notifier).createFolder(
                              name: nameCtrl.text.trim(),
                              parentId: _currentFolderId,
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
    );
  }

  void _showBookmarkContextMenu(BookmarkModel bookmark) {
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.globe, color: colors.primary, size: 18),
                ),
                title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(LucideIcons.externalLink, size: 20),
                title: const Text('Open in New Tab'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _openBookmark(bookmark);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.edit3, size: 20),
                title: const Text('Edit Bookmark'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditBookmarkDialog(bookmark);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.folderInput, size: 20),
                title: const Text('Move to Folder'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveFolderPicker(bookmark);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2, size: 20),
                title: const Text('Share Link'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      uri: Uri.tryParse(bookmark.url),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.error, size: 20),
                title: Text('Delete Bookmark', style: TextStyle(color: colors.error, fontWeight: FontWeight.w600)),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(bookmarksProvider.notifier).removeBookmark(bookmark.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBookmarkDialog(BookmarkModel bookmark) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final titleCtrl = TextEditingController(text: bookmark.title);
    final urlCtrl = TextEditingController(text: bookmark.url);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'Edit Bookmark',
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
                labelText: 'Title',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                  borderSide: BorderSide(color: colors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
            ),
            const SizedBox(height: TxSpacing.sm),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
              decoration: InputDecoration(
                labelText: 'URL',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                  borderSide: BorderSide(color: colors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
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
                    label: 'Save Changes',
                    onPressed: () {
                      if (urlCtrl.text.trim().isNotEmpty) {
                        ref.read(bookmarksProvider.notifier).updateBookmark(
                              id: bookmark.id,
                              title: titleCtrl.text.trim(),
                              url: urlCtrl.text.trim(),
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
    );
  }

  void _showMoveFolderPicker(BookmarkModel bookmark) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final folders = ref.read(bookmarksProvider).folders;

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
                'Move Bookmark',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ListTile(
                leading: const Icon(LucideIcons.folder),
                title: const Text('Bookmarks (Root)'),
                trailing: bookmark.folderId == null
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(bookmarksProvider.notifier).moveBookmark(
                        id: bookmark.id,
                        targetFolderId: null,
                      );
                  Navigator.pop(ctx);
                },
              ),
              ...folders.map(
                (f) => ListTile(
                  leading: const Icon(LucideIcons.folder),
                  title: Text(f.name),
                  trailing: bookmark.folderId == f.id
                      ? Icon(LucideIcons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    ref.read(bookmarksProvider.notifier).moveBookmark(
                          id: bookmark.id,
                          targetFolderId: f.id,
                        );
                    Navigator.pop(ctx);
                  },
                ),
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
    final bookmarksState = ref.watch(bookmarksProvider);

    // Current folder name
    String folderTitle = 'Bookmarks';
    if (_currentFolderId != null) {
      final curFolder = bookmarksState.folders
          .where((f) => f.id == _currentFolderId)
          .firstOrNull;
      if (curFolder != null) {
        folderTitle = curFolder.name;
      }
    }

    // Filter bookmarks
    List<BookmarkModel> displayedBookmarks;
    List<BookmarkFolderModel> displayedFolders = [];

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayedBookmarks = bookmarksState.bookmarks
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.url.toLowerCase().contains(q))
          .toList();
    } else {
      displayedBookmarks = bookmarksState.bookmarks
          .where((b) => b.folderId == _currentFolderId)
          .toList();
      displayedFolders = bookmarksState.folders
          .where((f) => f.parentId == _currentFolderId)
          .toList();
    }

    final isEmpty = displayedBookmarks.isEmpty && displayedFolders.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentFolderId != null) {
          setState(() => _currentFolderId = null);
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 22),
            tooltip: 'Back',
            onPressed: () {
              if (_currentFolderId != null) {
                setState(() => _currentFolderId = null);
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(folderTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.folderPlus, size: 20),
              tooltip: 'New Folder',
              onPressed: _showCreateFolderDialog,
            ),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 20),
              tooltip: 'Add Bookmark',
              onPressed: _showAddBookmarkDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: TxResponsiveContainer(
            maxWidth: 720,
            child: Column(
              children: [
                // Search filter
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
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search bookmarks...',
                        hintStyle:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: TxSpacing.xs),

                // Folder & Bookmark List
                Expanded(
                  child: isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(TxSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.bookmark,
                                    size: 32,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: TxSpacing.lg),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching bookmarks'
                                      : 'No bookmarks yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: TxSpacing.xs),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching for a different keyword or URL'
                                      : 'Save pages you want to quickly access later.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: TxSpacing.lg),
                                  TxButton(
                                    label: 'Add Bookmark',
                                    icon: LucideIcons.plus,
                                    onPressed: _showAddBookmarkDialog,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.lg,
                            vertical: TxSpacing.xs,
                          ),
                          children: [
                            // Folders
                            ...displayedFolders.map(
                              (folder) => Card(
                                elevation: 0,
                                color: colors.surface,
                                margin: const EdgeInsets.only(bottom: TxSpacing.xs),
                                shape: RoundedRectangleBorder(
                                  borderRadius: TxRadius.borderRadiusSm,
                                  side: BorderSide(color: colors.border),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    LucideIcons.folder,
                                    color: colors.primary,
                                    size: 22,
                                  ),
                                  title: Text(
                                    folder.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                                  onTap: () {
                                    setState(() {
                                      _currentFolderId = folder.id;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // Bookmarks
                            ...displayedBookmarks.map(
                              (bm) => Card(
                                elevation: 0,
                                color: colors.surface,
                                margin: const EdgeInsets.only(bottom: TxSpacing.xs),
                                shape: RoundedRectangleBorder(
                                  borderRadius: TxRadius.borderRadiusSm,
                                  side: BorderSide(color: colors.border),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      LucideIcons.globe,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    bm.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    bm.url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(LucideIcons.moreVertical, size: 18),
                                    onPressed: () => _showBookmarkContextMenu(bm),
                                  ),
                                  onTap: () => _openBookmark(bm),
                                ),
                              ),
                            ),

                            const SizedBox(height: TxSpacing.xs),
                            const TxNativeAdCard(
                              variant: TxAdSizeVariant.standardBanner,
                              margin: EdgeInsets.only(top: TxSpacing.xs),
                            ),
                          ],
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
