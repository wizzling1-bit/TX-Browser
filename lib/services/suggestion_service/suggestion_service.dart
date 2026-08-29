import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/constants/search_engines.dart';
import '../../core/utils/url_utils.dart';
import '../../data/database/app_database.dart';
import '../../state/shortcuts_provider.dart';
import 'suggestion_model.dart';

/// Aggregates and ranks search and URL suggestions.
class SuggestionService {
  const SuggestionService();

  /// Returns prioritized suggestions for the user's input [query].
  Future<List<SearchSuggestion>> getSuggestions({
    required String query,
    required AppDatabase db,
    required List<ShortcutModel> shortcuts,
    required SearchEngine engine,
    http.Client? httpClient,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final suggestions = <SearchSuggestion>[];
    final seenUrls = <String>{};

    // ─── 1. EXACT / INTENDED URL MATCH ──────────────────────────────
    if (UrlUtils.isUrl(trimmed)) {
      final normalized = UrlUtils.normalizeUrl(trimmed) ?? 'https://$trimmed';
      final domain = UrlUtils.extractDomain(normalized);
      suggestions.add(
        SearchSuggestion(
          title: 'Open $domain',
          url: normalized,
          domain: domain,
          type: SuggestionType.urlMatch,
        ),
      );
      seenUrls.add(normalized.toLowerCase());
    }

    // ─── 2. BROWSING HISTORY MATCHES ────────────────────────────────
    try {
      final historyEntries = await db.searchHistory(trimmed);
      for (final entry in historyEntries.take(4)) {
        final normUrl = entry.url.toLowerCase();
        if (!seenUrls.contains(normUrl)) {
          seenUrls.add(normUrl);
          suggestions.add(
            SearchSuggestion(
              title: entry.title.isNotEmpty ? entry.title : entry.url,
              url: entry.url,
              domain: UrlUtils.extractDomain(entry.url),
              faviconUrl: entry.faviconUrl,
              visitedAt: entry.visitedAt,
              type: SuggestionType.history,
            ),
          );
        }
      }
    } catch (_) {
      // Local history query error fallback
    }

    // ─── 3. PINNED / QUICK ACCESS SHORTCUTS MATCHES ─────────────────
    final qLower = trimmed.toLowerCase();
    for (final shortcut in shortcuts) {
      if (shortcut.label.toLowerCase().contains(qLower) ||
          shortcut.url.toLowerCase().contains(qLower)) {
        final normUrl = shortcut.url.toLowerCase();
        if (!seenUrls.contains(normUrl)) {
          seenUrls.add(normUrl);
          suggestions.add(
            SearchSuggestion(
              title: shortcut.label,
              url: shortcut.url,
              domain: UrlUtils.extractDomain(shortcut.url),
              type: SuggestionType.pinned,
            ),
          );
        }
      }
    }

    // ─── 4. SEARCH ENGINE PRIMARY ACTION ────────────────────────────
    final searchUrl = engine.searchUrl(trimmed);
    suggestions.add(
      SearchSuggestion(
        title: trimmed,
        url: searchUrl,
        subtitle: 'Search with ${engine.name}',
        type: SuggestionType.searchEngine,
      ),
    );

    // ─── 5. REMOTE SEARCH ENGINE SUGGESTIONS (DEBOUNCED) ────────────
    try {
      final remoteQueries = await _fetchRemoteSuggestions(trimmed, client: httpClient);
      for (final remoteQ in remoteQueries) {
        if (remoteQ.toLowerCase() != qLower && suggestions.length < 8) {
          final remoteUrl = engine.searchUrl(remoteQ);
          if (!seenUrls.contains(remoteUrl.toLowerCase())) {
            seenUrls.add(remoteUrl.toLowerCase());
            suggestions.add(
              SearchSuggestion(
                title: remoteQ,
                url: remoteUrl,
                subtitle: engine.name,
                type: SuggestionType.remoteSuggestion,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Network suggestion failure is silent and non-blocking
    }

    // Cap suggestions to maximum 7 items
    return suggestions.take(7).toList();
  }

  /// Fetches keyword suggestions from DuckDuckGo autocomplete API.
  Future<List<String>> _fetchRemoteSuggestions(String query, {http.Client? client}) async {
    final uri = Uri.parse(
      'https://duckduckgo.com/ac/?q=${Uri.encodeComponent(query)}&type=list',
    );

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0 TxBrowser/1.0'})
          .timeout(const Duration(milliseconds: 1400));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.length >= 2 && data[1] is List) {
          return (data[1] as List)
              .map((e) => e.toString())
              .take(3)
              .toList();
        }
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return const [];
  }
}
