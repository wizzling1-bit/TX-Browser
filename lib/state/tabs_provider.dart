import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Tab Group Model
// ---------------------------------------------------------------------------

class TabGroupModel {
  const TabGroupModel({
    required this.id,
    required this.title,
    this.colorValue = 0xFF609966,
    this.position = 0,
    required this.createdAt,
  });

  factory TabGroupModel.fromEntity(TabGroup entity) {
    return TabGroupModel(
      id: entity.id,
      title: entity.title,
      colorValue: entity.colorValue,
      position: entity.position,
      createdAt: entity.createdAt,
    );
  }

  final String id;
  final String title;
  final int colorValue;
  final int position;
  final DateTime createdAt;

  TabGroupModel copyWith({
    String? id,
    String? title,
    int? colorValue,
    int? position,
    DateTime? createdAt,
  }) {
    return TabGroupModel(
      id: id ?? this.id,
      title: title ?? this.title,
      colorValue: colorValue ?? this.colorValue,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Tab model (in-memory representation)
// ---------------------------------------------------------------------------

/// Lightweight model for a browser tab.
///
/// The actual [InAppWebViewController] is held in the browser engine service,
/// keyed by [id]. This keeps WebView objects out of the reactive tree
/// (TAD.md §4).
class TabModel {
  const TabModel({
    required this.id,
    this.url = '',
    this.title = 'New Tab',
    this.faviconUrl,
    this.isPrivate = false,
    this.isActive = false,
    this.isLoading = false,
    this.progress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.desktopSite = false,
    this.groupId,
    this.previewBytes,
  });

  final String id;
  final String url;
  final String title;
  final String? faviconUrl;
  final bool isPrivate;
  final bool isActive;
  final bool isLoading;
  final int progress; // 0–100
  final bool canGoBack;
  final bool canGoForward;
  final bool desktopSite;
  final String? groupId;
  final Uint8List? previewBytes;

  TabModel copyWith({
    String? url,
    String? title,
    String? faviconUrl,
    bool? isPrivate,
    bool? isActive,
    bool? isLoading,
    int? progress,
    bool? canGoBack,
    bool? canGoForward,
    bool? desktopSite,
    String? groupId,
    Uint8List? previewBytes,
    bool clearGroupId = false,
    bool clearFaviconUrl = false,
    bool clearPreviewBytes = false,
  }) {
    return TabModel(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      faviconUrl: clearFaviconUrl ? null : (faviconUrl ?? this.faviconUrl),
      isPrivate: isPrivate ?? this.isPrivate,
      isActive: isActive ?? this.isActive,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      desktopSite: desktopSite ?? this.desktopSite,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      previewBytes: clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently Closed Tab Model
// ---------------------------------------------------------------------------

class RecentlyClosedTab {
  const RecentlyClosedTab({
    required this.id,
    required this.url,
    required this.title,
    this.faviconUrl,
    required this.closedAt,
  });

  final String id;
  final String url;
  final String title;
  final String? faviconUrl;
  final DateTime closedAt;
}

// ---------------------------------------------------------------------------
// Tabs state
// ---------------------------------------------------------------------------

class TabsState {
  const TabsState({
    this.tabs = const [],
    this.groups = const [],
    this.activeTabId,
  });

  final List<TabModel> tabs;
  final List<TabGroupModel> groups;
  final String? activeTabId;

  TabModel? get activeTab {
    if (activeTabId == null) return null;
    try {
      return tabs.firstWhere((t) => t.id == activeTabId);
    } catch (_) {
      return null;
    }
  }

  int get count => tabs.length;

  TabsState copyWith({
    List<TabModel>? tabs,
    List<TabGroupModel>? groups,
    String? activeTabId,
    bool clearActiveTab = false,
  }) {
    return TabsState(
      tabs: tabs ?? this.tabs,
      groups: groups ?? this.groups,
      activeTabId: clearActiveTab ? null : (activeTabId ?? this.activeTabId),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently Closed Tabs Notifier
// ---------------------------------------------------------------------------

class RecentlyClosedNotifier extends Notifier<List<RecentlyClosedTab>> {
  static const _uuid = Uuid();

  @override
  List<RecentlyClosedTab> build() => const [];

  void pushTab(TabModel tab) {
    if (tab.isPrivate) return; // Strict SECURITY.md privacy rule
    if (tab.url.trim().isEmpty && (tab.title == 'New Tab' || tab.title.isEmpty)) {
      return;
    }

    final entry = RecentlyClosedTab(
      id: _uuid.v4(),
      url: tab.url,
      title: tab.title.trim().isEmpty ? 'Untitled Page' : tab.title,
      faviconUrl: tab.faviconUrl,
      closedAt: DateTime.now(),
    );

    // Keep up to 30 most recent, deduped by URL
    state = [entry, ...state.where((e) => e.url != entry.url)].take(30).toList();
  }

  void removeTab(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void clearAll() {
    state = const [];
  }
}

final recentlyClosedProvider =
    NotifierProvider<RecentlyClosedNotifier, List<RecentlyClosedTab>>(
  RecentlyClosedNotifier.new,
);

// ---------------------------------------------------------------------------
// Tabs notifier (Riverpod 3 Notifier)
// ---------------------------------------------------------------------------

class TabsNotifier extends Notifier<TabsState> {
  static const _uuid = Uuid();

  @override
  TabsState build() {
    return const TabsState();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Loads persisted tabs and tab groups from Drift on cold start.
  /// Purges any private tabs that survived a process kill.
  Future<void> restoreTabs() async {
    // Purge private tabs (SECURITY.md §3)
    await _db.deletePrivateTabs();

    final dbTabs = await _db.getAllTabs();
    final dbGroups = await _db.getAllTabGroups();

    final groupModels = dbGroups.map(TabGroupModel.fromEntity).toList();

    if (dbTabs.isEmpty) {
      state = TabsState(groups: groupModels);
      return;
    }

    final models = dbTabs.map((t) => TabModel(
          id: t.id,
          url: t.url,
          title: t.title,
          faviconUrl: t.faviconUrl,
          isPrivate: t.isPrivate,
          isActive: t.isActive,
          groupId: t.groupId,
        )).toList();

    final activeId = models.where((t) => t.isActive).firstOrNull?.id ??
        models.first.id;

    state = TabsState(
      tabs: models,
      groups: groupModels,
      activeTabId: activeId,
    );
  }

  /// Opens a new tab. Returns the tab ID.
  String openTab({String? url, bool isPrivate = false, String? groupId}) {
    final id = _uuid.v4();
    final tab = TabModel(
      id: id,
      url: url ?? '',
      title: (url != null && url.isNotEmpty) ? url : 'New Tab',
      isPrivate: isPrivate,
      isActive: true,
      groupId: groupId,
    );

    // Deactivate all other tabs immutably
    final updatedTabs = state.tabs.map((t) {
      return t.copyWith(isActive: false);
    }).toList()
      ..add(tab);

    state = state.copyWith(tabs: updatedTabs, activeTabId: id);
    return id;
  }

  /// Alias for openTab with clear naming.
  String newTab({String? url, bool isPrivate = false, String? groupId}) {
    return openTab(url: url, isPrivate: isPrivate, groupId: groupId);
  }

  /// Opens a URL in the active tab, or creates one if none exists.
  void openUrl(String url) {
    if (state.activeTab != null) {
      updateTab(state.activeTab!.id, (tab) => tab.copyWith(url: url));
    } else {
      openTab(url: url);
    }
  }

  /// Closes a tab by ID.
  void closeTab(String id) {
    final tabToClose = state.tabs.where((t) => t.id == id).firstOrNull;
    if (tabToClose != null) {
      ref.read(recentlyClosedProvider.notifier).pushTab(tabToClose);
    }

    final tabs = state.tabs.where((t) => t.id != id).toList();

    String? nextActiveId;
    List<TabModel> updatedTabs = tabs;

    if (tabs.isNotEmpty) {
      if (state.activeTabId == id) {
        // Activate the last tab (most recently used)
        nextActiveId = tabs.last.id;
        updatedTabs = tabs.map((t) {
          return t.copyWith(isActive: t.id == nextActiveId);
        }).toList();
      } else {
        nextActiveId = state.activeTabId;
      }
    }

    state = state.copyWith(
      tabs: updatedTabs,
      activeTabId: nextActiveId,
      clearActiveTab: nextActiveId == null,
    );

    // Remove from DB (non-private only)
    _db.deleteTab(id);
  }

  /// Switches to a tab.
  void switchToTab(String id) {
    final tabs = state.tabs.map((t) {
      return t.copyWith(isActive: t.id == id);
    }).toList();

    state = state.copyWith(tabs: tabs, activeTabId: id);
  }

  /// Reorders tabs (for drag-and-drop spatial reordering).
  void reorderTabs(int oldIndex, int newIndex) {
    final tabs = List<TabModel>.from(state.tabs);
    if (oldIndex < 0 || oldIndex >= tabs.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= tabs.length) return;

    final item = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, item);

    state = state.copyWith(tabs: tabs);
    persistTabs();
  }

  /// Updates the screenshot thumbnail preview for a tab.
  void updateTabThumbnail(String tabId, Uint8List thumbnailBytes) {
    state = state.copyWith(
      tabs: state.tabs.map((t) {
        if (t.id == tabId) {
          return t.copyWith(previewBytes: thumbnailBytes);
        }
        return t;
      }).toList(),
    );
  }

  /// Duplicates a tab by ID.
  String? duplicateTab(String id) {
    final existing = state.tabs.where((t) => t.id == id).firstOrNull;
    if (existing == null) return null;

    final newId = _uuid.v4();
    final duplicated = TabModel(
      id: newId,
      url: existing.url,
      title: existing.title,
      faviconUrl: existing.faviconUrl,
      isPrivate: existing.isPrivate,
      isActive: true,
      groupId: existing.groupId,
    );

    final updatedTabs = state.tabs.map((t) {
      return t.copyWith(isActive: false);
    }).toList()
      ..add(duplicated);

    state = state.copyWith(tabs: updatedTabs, activeTabId: newId);
    persistTabs();
    return newId;
  }

  /// Closes other tabs in the current scope.
  void closeOtherTabs(String id, {bool? isPrivate}) {
    final target = state.tabs.where((t) => t.id == id).firstOrNull;
    if (target == null) return;

    final closing = state.tabs.where((t) {
      if (t.id == id) return false;
      if (isPrivate != null && t.isPrivate != isPrivate) return false;
      return true;
    }).toList();

    for (final tab in closing) {
      ref.read(recentlyClosedProvider.notifier).pushTab(tab);
      _db.deleteTab(tab.id);
    }

    final remaining = state.tabs.where((t) {
      if (t.id == id) return true;
      if (isPrivate != null && t.isPrivate != isPrivate) return true;
      return false;
    }).map((t) {
      return t.copyWith(isActive: t.id == id);
    }).toList();

    state = state.copyWith(tabs: remaining, activeTabId: id);
    persistTabs();
  }

  /// Closes all tabs in the given scope (all regular or all private).
  void closeAllTabs({bool? isPrivate}) {
    if (isPrivate == null) {
      for (final t in state.tabs) {
        ref.read(recentlyClosedProvider.notifier).pushTab(t);
      }
      state = state.copyWith(tabs: [], clearActiveTab: true);
      _db.deleteAllTabs();
    } else {
      final closing = state.tabs.where((t) => t.isPrivate == isPrivate).toList();
      for (final t in closing) {
        ref.read(recentlyClosedProvider.notifier).pushTab(t);
        _db.deleteTab(t.id);
      }
      final remaining = state.tabs.where((t) => t.isPrivate != isPrivate).toList();
      final nextActive = remaining.firstOrNull?.id;
      final updatedRemaining = remaining.map((t) {
        return t.copyWith(isActive: t.id == nextActive);
      }).toList();

      state = state.copyWith(
        tabs: updatedRemaining,
        activeTabId: nextActive,
        clearActiveTab: nextActive == null,
      );
    }
  }

  void closeGroupTabs(String groupId) {
    final closing = state.tabs.where((t) => t.groupId == groupId).toList();
    for (final tab in closing) {
      ref.read(recentlyClosedProvider.notifier).pushTab(tab);
      _db.deleteTab(tab.id);
    }

    final remaining = state.tabs.where((t) => t.groupId != groupId).toList();
    final nextActive = remaining.firstOrNull?.id;
    final updatedRemaining = remaining.map((t) {
      return t.copyWith(isActive: t.id == nextActive);
    }).toList();

    state = state.copyWith(
      tabs: updatedRemaining,
      activeTabId: nextActive,
      clearActiveTab: nextActive == null,
    );
  }

  /// Restores a recently closed tab.
  String restoreClosedTab(RecentlyClosedTab closed) {
    ref.read(recentlyClosedProvider.notifier).removeTab(closed.id);
    return openTab(url: closed.url);
  }

  /// Updates a tab's metadata (URL, title, favicon, loading state, etc.)
  void updateTab(String id, TabModel Function(TabModel) updater) {
    final tabs = state.tabs.map((t) {
      if (t.id == id) return updater(t);
      return t;
    }).toList();

    state = state.copyWith(tabs: tabs);
  }

  // ---------------------------------------------------------------------------
  // Tab Group Actions
  // ---------------------------------------------------------------------------

  Future<void> createGroup({required String title, int colorValue = 0xFF609966}) async {
    final id = _uuid.v4();
    final group = TabGroupModel(
      id: id,
      title: title.trim().isEmpty ? 'New Group' : title.trim(),
      colorValue: colorValue,
      position: state.groups.length,
      createdAt: DateTime.now(),
    );

    await _db.insertTabGroup(
      TabGroupsCompanion.insert(
        id: id,
        title: group.title,
        colorValue: Value(group.colorValue),
        position: Value(group.position),
      ),
    );

    state = state.copyWith(groups: [...state.groups, group]);
  }

  Future<void> renameGroup({required String groupId, required String newTitle}) async {
    final title = newTitle.trim().isEmpty ? 'Group' : newTitle.trim();
    await _db.updateTabGroup(
      TabGroupsCompanion(
        id: Value(groupId),
        title: Value(title),
      ),
    );

    final updated = state.groups.map((g) {
      if (g.id == groupId) return g.copyWith(title: title);
      return g;
    }).toList();

    state = state.copyWith(groups: updated);
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.deleteTabGroup(groupId);

    // Unassign tabs belonging to this group
    final updatedTabs = state.tabs.map((t) {
      if (t.groupId == groupId) {
        return t.copyWith(groupId: null);
      }
      return t;
    }).toList();

    final updatedGroups = state.groups.where((g) => g.id != groupId).toList();
    state = state.copyWith(tabs: updatedTabs, groups: updatedGroups);
  }

  void assignTabToGroup({required String tabId, String? groupId}) {
    updateTab(tabId, (t) => t.copyWith(groupId: groupId));
    persistTabs();
  }



  /// Persists current tab state to Drift (non-private tabs only per SECURITY.md §3).
  /// Called on app background / lifecycle pause.
  Future<void> persistTabs() async {
    final db = _db;
    final nonPrivateTabs = state.tabs.where((t) => !t.isPrivate).toList();
    // Delete all existing rows and re-insert
    await db.deleteAllTabs();

    for (var i = 0; i < nonPrivateTabs.length; i++) {
      final tab = nonPrivateTabs[i];
      await db.insertTab(TabsCompanion.insert(
        id: tab.id,
        url: Value(tab.url),
        title: Value(tab.title),
        faviconUrl: Value(tab.faviconUrl),
        position: Value(i),
        isActive: Value(tab.isActive),
        isPrivate: const Value(false),
        groupId: Value(tab.groupId),
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tabsProvider =
    NotifierProvider<TabsNotifier, TabsState>(TabsNotifier.new);
