import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/suggestion_service/suggestion_model.dart';
import '../services/suggestion_service/suggestion_service.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'shortcuts_provider.dart';

class SuggestionsState {
  const SuggestionsState({
    this.query = '',
    this.suggestions = const [],
    this.isLoading = false,
  });

  final String query;
  final List<SearchSuggestion> suggestions;
  final bool isLoading;

  SuggestionsState copyWith({
    String? query,
    List<SearchSuggestion>? suggestions,
    bool? isLoading,
  }) {
    return SuggestionsState(
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SuggestionsNotifier extends Notifier<SuggestionsState> {
  Timer? _debounceTimer;
  final SuggestionService _service = const SuggestionService();

  @override
  SuggestionsState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const SuggestionsState();
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      state = const SuggestionsState();
      return;
    }

    state = state.copyWith(query: query, isLoading: true);

    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      final db = ref.read(databaseProvider);
      final shortcuts = ref.read(shortcutsProvider);
      final engine = ref.read(settingsProvider).searchEngine;

      final results = await _service.getSuggestions(
        query: trimmed,
        db: db,
        shortcuts: shortcuts,
        engine: engine,
      );

      if (state.query == query) {
        state = SuggestionsState(
          query: query,
          suggestions: results,
          isLoading: false,
        );
      }
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const SuggestionsState();
  }
}

final suggestionsProvider =
    NotifierProvider<SuggestionsNotifier, SuggestionsState>(
  SuggestionsNotifier.new,
);
