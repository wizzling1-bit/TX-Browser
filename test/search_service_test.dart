import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/constants/search_engines.dart';
import 'package:tx_browser/services/search_service/search_service.dart';

void main() {
  group('SearchService', () {
    const service = SearchService();

    test('resolves direct URL without search engine wrapping', () {
      expect(
        service.resolve('https://flutter.dev'),
        equals('https://flutter.dev'),
      );
      expect(
        service.resolve('flutter.dev'),
        equals('https://flutter.dev'),
      );
    });

    test('resolves search queries via DuckDuckGo by default', () {
      expect(
        service.resolve('flutter state management'),
        equals('https://duckduckgo.com/?q=flutter%20state%20management'),
      );
    });

    test('resolves search queries with configured search engine', () {
      expect(
        service.resolve('flutter', engine: SearchEngine.google),
        equals('https://www.google.com/search?q=flutter'),
      );
      expect(
        service.resolve('privacy', engine: SearchEngine.braveSearch),
        equals('https://search.brave.com/search?q=privacy'),
      );
      expect(
        service.resolve('news', engine: SearchEngine.bing),
        equals('https://www.bing.com/search?q=news'),
      );
    });
  });
}
