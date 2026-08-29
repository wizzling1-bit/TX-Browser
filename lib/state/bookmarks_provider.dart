import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import 'database_provider.dart';

class BookmarkModel {
  const BookmarkModel({
    required this.id,
    required this.title,
    required this.url,
    this.faviconUrl,
    this.folderId,
    required this.position,
    required this.createdAt,
  });

  factory BookmarkModel.fromEntity(Bookmark entity) {
    return BookmarkModel(
      id: entity.id,
      title: entity.title,
      url: entity.url,
      faviconUrl: entity.faviconUrl,
      folderId: entity.folderId,
      position: entity.position,
      createdAt: entity.createdAt,
    );
  }

  final String id;
  final String title;
  final String url;
  final String? faviconUrl;
  final String? folderId;
  final int position;
  final DateTime createdAt;

  BookmarkModel copyWith({
    String? id,
    String? title,
    String? url,
    String? faviconUrl,
    String? folderId,
    int? position,
    DateTime? createdAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      folderId: folderId ?? this.folderId,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BookmarkFolderModel {
  const BookmarkFolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.position,
    required this.createdAt,
  });

  factory BookmarkFolderModel.fromEntity(BookmarkFolder entity) {
    return BookmarkFolderModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      position: entity.position,
      createdAt: entity.createdAt,
    );
  }

  final String id;
  final String name;
  final String? parentId;
  final int position;
  final DateTime createdAt;
}

class BookmarksState {
  const BookmarksState({
    this.bookmarks = const [],
    this.folders = const [],
    this.isLoading = false,
  });

  final List<BookmarkModel> bookmarks;
  final List<BookmarkFolderModel> folders;
  final bool isLoading;

  BookmarksState copyWith({
    List<BookmarkModel>? bookmarks,
    List<BookmarkFolderModel>? folders,
    bool? isLoading,
  }) {
    return BookmarksState(
      bookmarks: bookmarks ?? this.bookmarks,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BookmarksNotifier extends Notifier<BookmarksState> {
  static const _uuid = Uuid();

  @override
  BookmarksState build() {
    loadBookmarks();
    return const BookmarksState(isLoading: true);
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> loadBookmarks() async {
    final bookmarksEntities = await _db.getAllBookmarks();
    final foldersEntities = await _db.getAllBookmarkFolders();

    state = BookmarksState(
      bookmarks: bookmarksEntities.map(BookmarkModel.fromEntity).toList(),
      folders: foldersEntities.map(BookmarkFolderModel.fromEntity).toList(),
      isLoading: false,
    );
  }

  Future<void> addBookmark({
    required String title,
    required String url,
    String? faviconUrl,
    String? folderId,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    final id = _uuid.v4();
    final position = state.bookmarks.length;
    final now = DateTime.now();

    await _db.insertBookmark(
      BookmarksCompanion.insert(
        id: id,
        title: title.trim().isEmpty ? cleanUrl : title.trim(),
        url: cleanUrl,
        faviconUrl: Value(faviconUrl),
        folderId: Value(folderId),
        position: Value(position),
        createdAt: Value(now),
      ),
    );

    await loadBookmarks();
  }

  Future<void> removeBookmark(String id) async {
    await _db.deleteBookmark(id);
    await loadBookmarks();
  }

  Future<void> removeBookmarkByUrl(String url) async {
    await _db.deleteBookmarkByUrl(url.trim());
    await loadBookmarks();
  }

  Future<void> updateBookmark({
    required String id,
    required String title,
    required String url,
    String? folderId,
  }) async {
    final existing = state.bookmarks.firstWhere((b) => b.id == id, orElse: () => state.bookmarks.first);
    await _db.updateBookmark(
      BookmarksCompanion(
        id: Value(id),
        title: Value(title.trim()),
        url: Value(url.trim()),
        folderId: Value(folderId),
        faviconUrl: Value(existing.faviconUrl),
      ),
    );
    await loadBookmarks();
  }

  Future<void> moveBookmark({required String id, String? targetFolderId}) async {
    final existing = state.bookmarks.firstWhere((b) => b.id == id, orElse: () => state.bookmarks.first);
    await _db.updateBookmark(
      BookmarksCompanion(
        id: Value(id),
        title: Value(existing.title),
        url: Value(existing.url),
        folderId: Value(targetFolderId),
        faviconUrl: Value(existing.faviconUrl),
      ),
    );
    await loadBookmarks();
  }

  Future<void> createFolder({required String name, String? parentId}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final id = _uuid.v4();
    final position = state.folders.length;

    await _db.insertBookmarkFolder(
      BookmarkFoldersCompanion.insert(
        id: id,
        name: cleanName,
        parentId: Value(parentId),
        position: Value(position),
      ),
    );

    await loadBookmarks();
  }

  Future<void> renameFolder({required String id, required String newName}) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    await _db.updateBookmarkFolder(
      BookmarkFoldersCompanion(
        id: Value(id),
        name: Value(cleanName),
      ),
    );

    await loadBookmarks();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteBookmarkFolder(id);
    await loadBookmarks();
  }

  bool isUrlBookmarked(String url) {
    if (url.trim().isEmpty) return false;
    final normalized = url.trim().toLowerCase();
    return state.bookmarks.any((b) {
      final bNorm = b.url.trim().toLowerCase();
      return bNorm == normalized || bNorm == '$normalized/' || '$bNorm/' == normalized;
    });
  }
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, BookmarksState>(
  BookmarksNotifier.new,
);

final isBookmarkedProvider = Provider.family<bool, String>((ref, url) {
  final bookmarksState = ref.watch(bookmarksProvider);
  if (url.trim().isEmpty) return false;
  final normalized = url.trim().toLowerCase();
  return bookmarksState.bookmarks.any((b) {
    final bNorm = b.url.trim().toLowerCase();
    return bNorm == normalized || bNorm == '$normalized/' || '$bNorm/' == normalized;
  });
});
