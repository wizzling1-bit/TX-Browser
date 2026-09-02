/// Search engine definitions for Tx Browser.
///
/// Google is the default. Users can change via Settings.
/// See PRD §6.1.
library;

enum SearchEngine {
  google(
    name: 'Google',
    urlTemplate: 'https://www.google.com/search?q={query}',
    iconAsset: 'google',
  ),
  duckDuckGo(
    name: 'DuckDuckGo',
    urlTemplate: 'https://duckduckgo.com/?q={query}',
    iconAsset: 'duckduckgo',
  ),
  bing(
    name: 'Bing',
    urlTemplate: 'https://www.bing.com/search?q={query}',
    iconAsset: 'bing',
  ),
  braveSearch(
    name: 'Brave Search',
    urlTemplate: 'https://search.brave.com/search?q={query}',
    iconAsset: 'brave',
  );

  const SearchEngine({
    required this.name,
    required this.urlTemplate,
    required this.iconAsset,
  });

  final String name;
  final String urlTemplate;
  final String iconAsset;

  /// Builds a search URL for the given [query].
  String searchUrl(String query) {
    return urlTemplate.replaceAll(
      '{query}',
      Uri.encodeComponent(query),
    );
  }

  /// Finds a [SearchEngine] by its name, or returns [google] as default.
  static SearchEngine fromName(String? name) {
    if (name == null) return SearchEngine.google;
    return SearchEngine.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SearchEngine.google,
    );
  }
}
