import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:tx_browser/data/database/app_database.dart';
import 'package:tx_browser/state/database_provider.dart';
import 'package:tx_browser/state/tabs_provider.dart';

void main() {
  group('Tab Groups System Tests', () {
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

    test('Create group, assign tab to group, and close group tabs', () async {
      final notifier = container.read(tabsProvider.notifier);

      final tab1 = notifier.openTab(url: 'https://docs.flutter.dev');
      final tab2 = notifier.openTab(url: 'https://dart.dev');

      await notifier.createGroup(title: 'Flutter Study', colorValue: 0xFF4A90E2);
      final stateWithGroup = container.read(tabsProvider);
      expect(stateWithGroup.groups.length, equals(1));
      final groupId = stateWithGroup.groups.first.id;

      notifier.assignTabToGroup(tabId: tab1, groupId: groupId);
      final stateAssigned = container.read(tabsProvider);
      expect(stateAssigned.tabs.firstWhere((t) => t.id == tab1).groupId, equals(groupId));
      expect(stateAssigned.tabs.firstWhere((t) => t.id == tab2).groupId, isNull);

      notifier.closeGroupTabs(groupId);
      final stateAfterClose = container.read(tabsProvider);
      expect(stateAfterClose.tabs.length, equals(1));
      expect(stateAfterClose.tabs.first.id, equals(tab2));

      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
}
