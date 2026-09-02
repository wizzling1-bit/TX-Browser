import '../../core/constants/search_engines.dart';
import '../../core/utils/url_utils.dart';

/// Resolves user input into either a URL or a search query URL.
///
/// See SCREENWISE_FEATURES.md §3.

class SearchService {
  const SearchService();

  /// Given raw user input from the omnibox, returns a navigable URL.
  ///
  /// If [input] looks like a URL, normalizes and returns it.
  /// Otherwise, wraps it in the [engine]'s search URL template.
  String resolve(String input, {SearchEngine engine = SearchEngine.google}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return engine.searchUrl('');

    // Try to parse as a URL first.
    final normalized = UrlUtils.normalizeUrl(trimmed);
    if (normalized != null) return normalized;

    // It's a search query.
    return engine.searchUrl(trimmed);
  }
}
