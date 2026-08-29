import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/tabs.dart';
import 'tables/history.dart';
import 'tables/downloads.dart';
import 'tables/shortcuts.dart';
import 'tables/settings.dart';
import 'tables/bookmarks.dart';
import 'tables/site_permissions.dart';
import 'tables/tab_groups.dart';
import 'tables/content_blocking.dart';

part 'app_database.g.dart';

/// Tx Browser local database.
///
/// Single Drift/SQLite database — no backend, no Firebase, no Supabase.
/// All browsing data lives securely on-device.
///
/// See TAD.md §5.

@DriftDatabase(tables: [
  Tabs,
  HistoryEntries,
  Downloads,
  Shortcuts,
  Settings,
  Bookmarks,
  BookmarkFolders,
  SitePermissions,
  TabGroups,
  ContentBlockerExceptions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(bookmarkFolders);
            await m.createTable(bookmarks);
            await m.createTable(sitePermissions);
            await m.createTable(tabGroups);
            await m.createTable(contentBlockerExceptions);
            await m.addColumn(tabs, tabs.groupId);
          }
          if (from < 3) {
            await m.addColumn(downloads, downloads.androidDownloadId);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'tx_browser',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Future<List<Tab>> getAllTabs() =>
      (select(tabs)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();

  Future<void> insertTab(TabsCompanion tab) => into(tabs).insert(tab);

  Future<void> updateTab(TabsCompanion tab) =>
      (update(tabs)..where((t) => t.id.equals(tab.id.value)))
          .write(tab);

  Future<void> deleteTab(String id) =>
      (delete(tabs)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllTabs() => delete(tabs).go();

  Future<void> deletePrivateTabs() =>
      (delete(tabs)..where((t) => t.isPrivate.equals(true))).go();

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<List<HistoryEntry>> getHistory({int? limit}) {
    final query = select(historyEntries)
      ..orderBy([(h) => OrderingTerm.desc(h.visitedAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<HistoryEntry>> searchHistory(String query) {
    final pattern = '%$query%';
    return (select(historyEntries)
          ..where(
              (h) => h.title.like(pattern) | h.url.like(pattern))
          ..orderBy([(h) => OrderingTerm.desc(h.visitedAt)]))
        .get();
  }

  Future<void> insertHistoryEntry(HistoryEntriesCompanion entry) =>
      into(historyEntries).insert(entry);

  Future<void> deleteHistoryEntry(String id) =>
      (delete(historyEntries)..where((h) => h.id.equals(id))).go();

  Future<void> clearAllHistory() => delete(historyEntries).go();

  // ---------------------------------------------------------------------------
  // Downloads
  // ---------------------------------------------------------------------------

  Future<List<Download>> getAllDownloads() =>
      (select(downloads)
            ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
          .get();

  Future<void> insertDownload(DownloadsCompanion download) =>
      into(downloads).insert(download);

  Future<void> updateDownload(DownloadsCompanion download) =>
      (update(downloads)..where((d) => d.id.equals(download.id.value)))
          .write(download);

  Future<void> deleteDownload(String id) =>
      (delete(downloads)..where((d) => d.id.equals(id))).go();

  Future<void> clearAllDownloads() => delete(downloads).go();

  // ---------------------------------------------------------------------------
  // Shortcuts
  // ---------------------------------------------------------------------------

  Future<List<Shortcut>> getAllShortcuts() =>
      (select(shortcuts)
            ..orderBy([(s) => OrderingTerm.asc(s.position)]))
          .get();

  Stream<List<Shortcut>> watchAllShortcuts() =>
      (select(shortcuts)
            ..orderBy([(s) => OrderingTerm.asc(s.position)]))
          .watch();

  Future<void> insertShortcut(ShortcutsCompanion shortcut) =>
      into(shortcuts).insert(shortcut);

  Future<void> updateShortcut(ShortcutsCompanion shortcut) =>
      (update(shortcuts)..where((s) => s.id.equals(shortcut.id.value)))
          .write(shortcut);

  Future<void> deleteShortcut(String id) =>
      (delete(shortcuts)..where((s) => s.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final result = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value),
      );

  Future<void> deleteSetting(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();

  Stream<String?> watchSetting(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  // ---------------------------------------------------------------------------
  // Bookmarks & Folders
  // ---------------------------------------------------------------------------

  Future<List<BookmarkFolder>> getAllBookmarkFolders() =>
      (select(bookmarkFolders)..orderBy([(f) => OrderingTerm.asc(f.position)])).get();

  Stream<List<BookmarkFolder>> watchAllBookmarkFolders() =>
      (select(bookmarkFolders)..orderBy([(f) => OrderingTerm.asc(f.position)])).watch();

  Future<void> insertBookmarkFolder(BookmarkFoldersCompanion folder) =>
      into(bookmarkFolders).insert(folder);

  Future<void> updateBookmarkFolder(BookmarkFoldersCompanion folder) =>
      (update(bookmarkFolders)..where((f) => f.id.equals(folder.id.value)))
          .write(folder);

  Future<void> deleteBookmarkFolder(String id) async {
    // Delete bookmarks in folder or move to root
    await (delete(bookmarks)..where((b) => b.folderId.equals(id))).go();
    await (delete(bookmarkFolders)..where((f) => f.id.equals(id))).go();
  }

  Future<List<Bookmark>> getAllBookmarks() =>
      (select(bookmarks)..orderBy([(b) => OrderingTerm.asc(b.position)])).get();

  Stream<List<Bookmark>> watchAllBookmarks() =>
      (select(bookmarks)..orderBy([(b) => OrderingTerm.asc(b.position)])).watch();

  Future<List<Bookmark>> getBookmarksInFolder(String? folderId) {
    if (folderId == null) {
      return (select(bookmarks)
            ..where((b) => b.folderId.isNull())
            ..orderBy([(b) => OrderingTerm.asc(b.position)]))
          .get();
    }
    return (select(bookmarks)
          ..where((b) => b.folderId.equals(folderId))
          ..orderBy([(b) => OrderingTerm.asc(b.position)]))
        .get();
  }

  Future<Bookmark?> getBookmarkByUrl(String url) =>
      (select(bookmarks)..where((b) => b.url.equals(url))).getSingleOrNull();

  Future<void> insertBookmark(BookmarksCompanion bookmark) =>
      into(bookmarks).insert(bookmark);

  Future<void> updateBookmark(BookmarksCompanion bookmark) =>
      (update(bookmarks)..where((b) => b.id.equals(bookmark.id.value)))
          .write(bookmark);

  Future<void> deleteBookmark(String id) =>
      (delete(bookmarks)..where((b) => b.id.equals(id))).go();

  Future<void> deleteBookmarkByUrl(String url) =>
      (delete(bookmarks)..where((b) => b.url.equals(url))).go();

  // ---------------------------------------------------------------------------
  // Tab Groups
  // ---------------------------------------------------------------------------

  Future<List<TabGroup>> getAllTabGroups() =>
      (select(tabGroups)..orderBy([(g) => OrderingTerm.asc(g.position)])).get();

  Stream<List<TabGroup>> watchAllTabGroups() =>
      (select(tabGroups)..orderBy([(g) => OrderingTerm.asc(g.position)])).watch();

  Future<void> insertTabGroup(TabGroupsCompanion group) =>
      into(tabGroups).insert(group);

  Future<void> updateTabGroup(TabGroupsCompanion group) =>
      (update(tabGroups)..where((g) => g.id.equals(group.id.value)))
          .write(group);

  Future<void> deleteTabGroup(String id) async {
    // Unassign group from tabs
    await (update(tabs)..where((t) => t.groupId.equals(id))).write(
      const TabsCompanion(groupId: Value(null)),
    );
    await (delete(tabGroups)..where((g) => g.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Site Permissions
  // ---------------------------------------------------------------------------

  Future<List<SitePermission>> getAllSitePermissions() =>
      select(sitePermissions).get();

  Stream<List<SitePermission>> watchAllSitePermissions() =>
      select(sitePermissions).watch();

  Future<SitePermission?> getSitePermission(String host, String permissionType) =>
      (select(sitePermissions)
            ..where((p) => p.host.equals(host) & p.permissionType.equals(permissionType)))
          .getSingleOrNull();

  Future<void> setSitePermission(SitePermissionsCompanion permission) =>
      into(sitePermissions).insertOnConflictUpdate(permission);

  Future<void> deleteSitePermission(String id) =>
      (delete(sitePermissions)..where((p) => p.id.equals(id))).go();

  Future<void> clearSitePermissionsForHost(String host) =>
      (delete(sitePermissions)..where((p) => p.host.equals(host))).go();

  // ---------------------------------------------------------------------------
  // Content Blocker Exceptions
  // ---------------------------------------------------------------------------

  Future<List<ContentBlockerException>> getAllBlockerExceptions() =>
      select(contentBlockerExceptions).get();

  Stream<List<ContentBlockerException>> watchAllBlockerExceptions() =>
      select(contentBlockerExceptions).watch();

  Future<void> setBlockerException(ContentBlockerExceptionsCompanion exception) =>
      into(contentBlockerExceptions).insertOnConflictUpdate(exception);

  Future<void> deleteBlockerException(String host) =>
      (delete(contentBlockerExceptions)..where((e) => e.host.equals(host))).go();
}
