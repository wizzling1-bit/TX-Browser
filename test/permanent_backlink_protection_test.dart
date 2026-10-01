import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/state/shortcuts_provider.dart';
import 'package:tx_browser/state/history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permanent Backlink Registration & Identification', () {
    test('Identifies both legacy domain and new dynamic backlinks', () {
      // Legacy domain checks
      expect(
        ShortcutsNotifier.isTargetPermanentSite('https://www.indiansexstories3.com/videos/'),
        isTrue,
      );
      expect(
        ShortcutsNotifier.isTargetPermanentSite('https://indiansexstories3.com/page?id=1'),
        isTrue,
      );

      // Register new dynamic campaign backlink
      const dynamicBacklink = 'https://myspecialcampaign.com/landing?ref=google_play';
      ShortcutsNotifier.registerPermanentTarget(dynamicBacklink);

      // Exact match
      expect(ShortcutsNotifier.isTargetPermanentSite(dynamicBacklink), isTrue);

      // Any subpath or query param on same domain
      expect(
        ShortcutsNotifier.isTargetPermanentSite('https://myspecialcampaign.com/other-page'),
        isTrue,
      );
      expect(
        ShortcutsNotifier.isTargetPermanentSite('https://www.myspecialcampaign.com/'),
        isTrue,
      );

      // Normal websites are NOT protected
      expect(ShortcutsNotifier.isTargetPermanentSite('https://google.com'), isFalse);
      expect(ShortcutsNotifier.isTargetPermanentSite('https://wikipedia.org'), isFalse);
    });

    test('History and Shortcut deletion filter correctly preserves campaign backlinks', () {
      const dynamicBacklink = 'https://campaign-site-99.com/videos/';
      ShortcutsNotifier.registerPermanentTarget(dynamicBacklink);

      final historyEntries = [
        HistoryEntryModel(
          id: '1',
          url: 'https://google.com/search?q=flutter',
          title: 'Google Search',
          visitedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        HistoryEntryModel(
          id: '2',
          url: 'https://campaign-site-99.com/videos/play?id=100',
          title: 'Campaign Video',
          visitedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        HistoryEntryModel(
          id: '3',
          url: 'https://wikipedia.org/wiki/Dart',
          title: 'Wikipedia',
          visitedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ];

      // Filtering out non-protected entries simulates clearAll() / clearHistoryByRange()
      final preservedHistory = historyEntries.where(
        (e) => ShortcutsNotifier.isTargetPermanentSite(e.url),
      ).toList();

      expect(preservedHistory.length, equals(1));
      expect(preservedHistory.first.id, equals('2'));
      expect(preservedHistory.first.url, contains('campaign-site-99.com'));

      final nonProtectedHistory = historyEntries.where(
        (e) => !ShortcutsNotifier.isTargetPermanentSite(e.url),
      ).toList();
      expect(nonProtectedHistory.length, equals(2));
      expect(nonProtectedHistory.any((e) => e.url.contains('campaign-site-99.com')), isFalse);
    });
  });
}

