import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import 'package:tx_browser/core/constants/search_engines.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/data/database/app_database.dart';
import 'package:tx_browser/services/suggestion_service/suggestion_model.dart';
import 'package:tx_browser/services/suggestion_service/suggestion_service.dart';
import 'package:tx_browser/state/shortcuts_provider.dart';
import 'package:tx_browser/widgets/search/search_suggestions_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SuggestionService Unit Tests', () {
    late AppDatabase db;
    late http.Client mockClient;
    const service = SuggestionService();

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      mockClient = MockClient((request) async {
        return http.Response('["you", ["youtube", "youtube music", "youtube studio"]]', 200);
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Identifies valid direct URLs and creates urlMatch suggestion', () async {
      final suggestions = await service.getSuggestions(
        query: 'flutter.dev',
        db: db,
        shortcuts: [],
        engine: SearchEngine.duckDuckGo,
        httpClient: mockClient,
      );

      expect(suggestions.isNotEmpty, isTrue);
      final urlMatch = suggestions.firstWhere((s) => s.type == SuggestionType.urlMatch);
      expect(urlMatch.url, equals('https://flutter.dev'));
      expect(urlMatch.domain, equals('flutter.dev'));
    });

    test('Includes configured search engine action for search queries', () async {
      final suggestions = await service.getSuggestions(
        query: 'best flutter widgets',
        db: db,
        shortcuts: [],
        engine: SearchEngine.duckDuckGo,
        httpClient: mockClient,
      );

      final searchAction =
          suggestions.firstWhere((s) => s.type == SuggestionType.searchEngine);
      expect(searchAction.title, equals('best flutter widgets'));
      expect(searchAction.subtitle, contains('DuckDuckGo'));
      expect(searchAction.url, contains('duckduckgo.com/?q=best%20flutter%20widgets'));
    });

    test('Matches pinned shortcuts by name or url', () async {
      final shortcuts = [
        ShortcutModel(
          id: '1',
          label: 'YouTube',
          url: 'https://youtube.com',
          position: 0,
        ),
      ];

      final suggestions = await service.getSuggestions(
        query: 'you',
        db: db,
        shortcuts: shortcuts,
        engine: SearchEngine.google,
        httpClient: mockClient,
      );

      final pinned = suggestions.where((s) => s.type == SuggestionType.pinned);
      expect(pinned.isNotEmpty, isTrue);
      expect(pinned.first.title, equals('YouTube'));
      expect(pinned.first.url, equals('https://youtube.com'));
    });
  });

  group('SearchSuggestionsPanel Widget Tests', () {
    testWidgets('Renders suggestions with title, subtitle, and fires callbacks',
        (tester) async {
      SearchSuggestion? selectedSuggestion;
      String? insertedText;

      final testSuggestions = [
        const SearchSuggestion(
          title: 'Open flutter.dev',
          url: 'https://flutter.dev',
          domain: 'flutter.dev',
          type: SuggestionType.urlMatch,
        ),
        const SearchSuggestion(
          title: 'flutter tutorial',
          url: 'https://duckduckgo.com/?q=flutter+tutorial',
          subtitle: 'Search with DuckDuckGo',
          type: SuggestionType.searchEngine,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [TxColorScheme.light],
          ),
          home: Scaffold(
            body: SearchSuggestionsPanel(
              suggestions: testSuggestions,
              isLoading: false,
              onSelect: (s) => selectedSuggestion = s,
              onInsert: (text) => insertedText = text,
            ),
          ),
        ),
      );

      expect(find.text('Open flutter.dev'), findsOneWidget);
      expect(find.text('flutter.dev'), findsOneWidget);
      expect(find.text('flutter tutorial'), findsOneWidget);
      expect(find.text('Search with DuckDuckGo'), findsOneWidget);

      // Tap on the first suggestion
      await tester.tap(find.text('Open flutter.dev'));
      await tester.pump();
      expect(selectedSuggestion?.url, equals('https://flutter.dev'));

      // Tap on the trailing insert button
      await tester.tap(find.byIcon(LucideIcons.arrowUpLeft).first);
      await tester.pump();
      expect(insertedText, equals('https://flutter.dev'));
    });
  });
}
