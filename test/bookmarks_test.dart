import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:tx_browser/data/database/app_database.dart';
import 'package:tx_browser/state/database_provider.dart';
import 'package:tx_browser/state/bookmarks_provider.dart';

void main() {
  group('Bookmarks System Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('Add, check, and remove bookmark', () async {
      final notifier = container.read(bookmarksProvider.notifier);

      expect(notifier.isUrlBookmarked('https://flutter.dev'), isFalse);

      await notifier.addBookmark(
        title: 'Flutter Dev',
        url: 'https://flutter.dev',
      );

      final state = container.read(bookmarksProvider);
      expect(state.bookmarks.length, equals(1));
      expect(state.bookmarks.first.title, equals('Flutter Dev'));
      expect(notifier.isUrlBookmarked('https://flutter.dev'), isTrue);

      await notifier.removeBookmarkByUrl('https://flutter.dev');
      final stateAfter = container.read(bookmarksProvider);
      expect(stateAfter.bookmarks.isEmpty, isTrue);
      expect(notifier.isUrlBookmarked('https://flutter.dev'), isFalse);
    });

    test('Create folder, move bookmark into folder, and delete folder', () async {
      final notifier = container.read(bookmarksProvider.notifier);

      await notifier.createFolder(name: 'Work');
      final stateWithFolder = container.read(bookmarksProvider);
      expect(stateWithFolder.folders.length, equals(1));
      final folderId = stateWithFolder.folders.first.id;

      await notifier.addBookmark(
        title: 'GitHub',
        url: 'https://github.com',
      );

      final bookmark = container.read(bookmarksProvider).bookmarks.first;
      expect(bookmark.folderId, isNull);

      await notifier.moveBookmark(id: bookmark.id, targetFolderId: folderId);
      final updatedBookmark = container.read(bookmarksProvider).bookmarks.first;
      expect(updatedBookmark.folderId, equals(folderId));

      await notifier.deleteFolder(folderId);
      final stateAfterFolderDelete = container.read(bookmarksProvider);
      expect(stateAfterFolderDelete.folders.isEmpty, isTrue);
      expect(stateAfterFolderDelete.bookmarks.isEmpty, isTrue);
    });
  });
}
