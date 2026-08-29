import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/state/tabs_provider.dart';
import 'package:tx_browser/state/downloads_provider.dart';
import 'package:tx_browser/services/download_service/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TabModel & TabsState Immutability Tests', () {
    test('TabModel copyWith preserves fields when not overridden', () {
      const tab = TabModel(
        id: 'tab-1',
        url: 'https://flutter.dev',
        title: 'Flutter',
        faviconUrl: 'https://flutter.dev/favicon.ico',
        isPrivate: false,
        isActive: true,
        isLoading: true,
        progress: 45,
        canGoBack: true,
        canGoForward: false,
        desktopSite: false,
      );

      final updated = tab.copyWith(
        title: 'Flutter - Build apps',
        progress: 100,
        isLoading: false,
      );

      expect(updated.id, equals('tab-1'));
      expect(updated.url, equals('https://flutter.dev'));
      expect(updated.title, equals('Flutter - Build apps'));
      expect(updated.faviconUrl, equals('https://flutter.dev/favicon.ico'));
      expect(updated.isLoading, isFalse);
      expect(updated.progress, equals(100));
      expect(updated.canGoBack, isTrue);
      expect(updated.canGoForward, isFalse);

      // Verify original is untouched
      expect(tab.title, equals('Flutter'));
      expect(tab.isLoading, isTrue);
      expect(tab.progress, equals(45));
    });

    test('TabsNotifier opens, switches, updates and manages tabs immutably', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tabsProvider.notifier);

      final tab1Id = notifier.openTab(url: 'https://example.com');
      final tab2Id = notifier.openTab(url: 'https://wikipedia.org');

      var state = container.read(tabsProvider);
      expect(state.count, equals(2));
      expect(state.activeTabId, equals(tab2Id));
      expect(state.activeTab?.url, equals('https://wikipedia.org'));

      // Switch to first tab
      notifier.switchToTab(tab1Id);
      state = container.read(tabsProvider);
      expect(state.activeTabId, equals(tab1Id));
      expect(state.tabs.firstWhere((t) => t.id == tab1Id).isActive, isTrue);
      expect(state.tabs.firstWhere((t) => t.id == tab2Id).isActive, isFalse);

      // Update tab title and favicon
      notifier.updateTab(tab1Id, (tab) {
        return tab.copyWith(
          title: 'Example Domain',
          faviconUrl: 'https://example.com/fav.png',
        );
      });

      state = container.read(tabsProvider);
      final updatedTab1 = state.tabs.firstWhere((t) => t.id == tab1Id);
      expect(updatedTab1.title, equals('Example Domain'));
      expect(updatedTab1.faviconUrl, equals('https://example.com/fav.png'));
    });
  });

  group('DownloadModel Tests', () {
    test('DownloadModel copyWith updates fields immutably', () {
      final now = DateTime.now();
      final download = DownloadModel(
        id: 'dl-1',
        fileName: 'app.apk',
        filePath: '',
        sourceUrl: 'https://example.com/app.apk',
        createdAt: now,
        status: DownloadStatus.downloading,
        progressPercent: 10,
      );

      final updated = download.copyWith(
        filePath: '/downloads/app.apk',
        status: DownloadStatus.completed,
        progressPercent: 100,
        sizeBytes: 1024000,
      );

      expect(updated.id, equals('dl-1'));
      expect(updated.filePath, equals('/downloads/app.apk'));
      expect(updated.status, equals(DownloadStatus.completed));
      expect(updated.progressPercent, equals(100));
      expect(updated.sizeBytes, equals(1024000));

      // Original is untouched
      expect(download.filePath, isEmpty);
      expect(download.status, equals(DownloadStatus.downloading));
      expect(download.progressPercent, equals(10));
    });
  });
}
