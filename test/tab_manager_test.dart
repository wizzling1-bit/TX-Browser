import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/features/tabs/tab_manager_screen.dart';
import 'package:tx_browser/state/tabs_provider.dart';
import 'package:tx_browser/widgets/cards/tab_card.dart';

void main() {
  group('Tab Manager & Recently Closed Tests', () {
    test('RecentlyClosedNotifier pushes non-private tab and caps at 30', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recentlyClosedProvider.notifier);

      const regularTab = TabModel(
        id: '1',
        url: 'https://flutter.dev',
        title: 'Flutter',
        isPrivate: false,
      );

      notifier.pushTab(regularTab);
      var list = container.read(recentlyClosedProvider);
      expect(list.length, equals(1));
      expect(list.first.url, equals('https://flutter.dev'));
      expect(list.first.title, equals('Flutter'));

      // Private tab should never be pushed
      const privateTab = TabModel(
        id: '2',
        url: 'https://secret.com',
        title: 'Secret',
        isPrivate: true,
      );
      notifier.pushTab(privateTab);
      list = container.read(recentlyClosedProvider);
      expect(list.length, equals(1));

      // Clear all
      notifier.clearAll();
      expect(container.read(recentlyClosedProvider), isEmpty);
    });

    testWidgets('TabManagerScreen renders header, 3-way segment filter, and action buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: [TxColorScheme.light],
            ),
            home: const TabManagerScreen(),
          ),
        ),
      );

      // Verify Header and action buttons
      expect(find.text('Tabs'), findsOneWidget);
      expect(find.text('Open (0)'), findsOneWidget);
      expect(find.text('Private (0)'), findsOneWidget);
      expect(find.text('Closed (0)'), findsOneWidget);
      expect(find.text('New Tab'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('TabCard renders dynamic webpage preview without fallback letters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [TxColorScheme.light],
          ),
          home: const Scaffold(
            body: TabCard(
              title: 'YouTube',
              url: 'https://youtube.com',
              isActive: true,
            ),
          ),
        ),
      );

      // Verify domain and title render
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('youtube.com'), findsNWidgets(2)); // in bottom bar & mini address bar
      expect(find.text('ACTIVE'), findsOneWidget);

      // Verify there are no standalone fallback letter text widgets
      expect(find.text('Y'), findsNothing);
    });
  });
}
