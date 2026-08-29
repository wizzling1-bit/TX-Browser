/// Types of search suggestions in Tx Browser autocomplete.
enum SuggestionType {
  urlMatch,
  history,
  pinned,
  searchEngine,
  remoteSuggestion,
}

/// A structured suggestion item displayed in the autocomplete panel.
class SearchSuggestion {
  const SearchSuggestion({
    required this.title,
    required this.url,
    required this.type,
    this.domain,
    this.subtitle,
    this.faviconUrl,
    this.visitedAt,
  });

  final String title;
  final String url;
  final SuggestionType type;
  final String? domain;
  final String? subtitle;
  final String? faviconUrl;
  final DateTime? visitedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuggestion &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          type == other.type;

  @override
  int get hashCode => url.hashCode ^ type.hashCode;
}
