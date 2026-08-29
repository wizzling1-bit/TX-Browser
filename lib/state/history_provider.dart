import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../data/database/app_database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// History Entry Model
// ---------------------------------------------------------------------------

class HistoryEntryModel {
  HistoryEntryModel({
    required this.id,
    required this.url,
    required this.title,
    this.faviconUrl,
    required this.visitedAt,
  });

  final String id;
  final String url;
  final String title;
  final String? faviconUrl;
  final DateTime visitedAt;

  String get formattedTime => DateFormat('h:mm a').format(visitedAt);

  String get domain {
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url;
    }
  }
}

// ---------------------------------------------------------------------------
// History Group Model (Date Grouping)
// ---------------------------------------------------------------------------

class HistoryGroup {
  const HistoryGroup({
    required this.title,
    required this.entries,
  });

  final String title;
  final List<HistoryEntryModel> entries;
}

// ---------------------------------------------------------------------------
// History Notifier (Riverpod 3)
// ---------------------------------------------------------------------------

class HistoryNotifier extends Notifier<List<HistoryEntryModel>> {
  static const _uuid = Uuid();

  static final _sampleRecent = [
    {
      'title': 'Figma',
      'url': 'https://figma.com',
      'ago': const Duration(minutes: 2),
    },
    {
      'title': 'Unsplash',
      'url': 'https://unsplash.com',
      'ago': const Duration(hours: 1),
    },
    {
      'title': 'Flutter Documentation',
      'url': 'https://docs.flutter.dev',
      'ago': const Duration(hours: 3),
    },
    {
      'title': 'GitHub',
      'url': 'https://github.com',
      'ago': const Duration(hours: 5),
    },
  ];

  @override
  List<HistoryEntryModel> build() {
    // Proactively load from SQLite database on initialization
    Future.microtask(() => loadHistory());
    return [];
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Load all history from Drift.
  Future<void> loadHistory() async {
    try {
      final entries = await _db.getHistory();
      state = entries
          .map((e) => HistoryEntryModel(
                id: e.id,
                url: e.url,
                title: e.title,
                faviconUrl: e.faviconUrl,
                visitedAt: e.visitedAt,
              ))
          .toList();
    } catch (_) {
      // Fallback in case table is initializing
    }
  }

  /// Load recent entries for Home screen.
  Future<List<HistoryEntryModel>> getRecent({int limit = 10}) async {
    try {
      final entries = await _db.getHistory(limit: limit);
      if (entries.isEmpty) {
        final now = DateTime.now();
        return _sampleRecent
            .map((item) => HistoryEntryModel(
                  id: (item['title'] as String).toLowerCase(),
                  url: item['url'] as String,
                  title: item['title'] as String,
                  visitedAt: now.subtract(item['ago'] as Duration),
                ))
            .toList();
      }
      return entries
          .map((e) => HistoryEntryModel(
                id: e.id,
                url: e.url,
                title: e.title,
                faviconUrl: e.faviconUrl,
                visitedAt: e.visitedAt,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Groups history into date sections: Today, Yesterday, Last 7 Days, Older.
  List<HistoryGroup> getGroupedHistory([String filterQuery = '']) {
    final filtered = filterQuery.isEmpty
        ? state
        : state.where((e) =>
            e.title.toLowerCase().contains(filterQuery.toLowerCase()) ||
            e.url.toLowerCase().contains(filterQuery.toLowerCase())).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final todayList = <HistoryEntryModel>[];
    final yesterdayList = <HistoryEntryModel>[];
    final lastWeekList = <HistoryEntryModel>[];
    final olderList = <HistoryEntryModel>[];

    for (final entry in filtered) {
      final entryDate = DateTime(
        entry.visitedAt.year,
        entry.visitedAt.month,
        entry.visitedAt.day,
      );

      if (entryDate == today) {
        todayList.add(entry);
      } else if (entryDate == yesterday) {
        yesterdayList.add(entry);
      } else if (entryDate.isAfter(lastWeek)) {
        lastWeekList.add(entry);
      } else {
        olderList.add(entry);
      }
    }

    final groups = <HistoryGroup>[];
    if (todayList.isNotEmpty) groups.add(HistoryGroup(title: 'Today', entries: todayList));
    if (yesterdayList.isNotEmpty) groups.add(HistoryGroup(title: 'Yesterday', entries: yesterdayList));
    if (lastWeekList.isNotEmpty) groups.add(HistoryGroup(title: 'Last 7 Days', entries: lastWeekList));
    if (olderList.isNotEmpty) groups.add(HistoryGroup(title: 'Older', entries: olderList));

    return groups;
  }

  /// Record a new visit with resilience and deduplication.
  Future<void> recordVisit({
    required String url,
    required String title,
    String? faviconUrl,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || cleanUrl == 'about:blank' || cleanUrl.startsWith('data:')) {
      return;
    }

    final now = DateTime.now();
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : cleanUrl;
    final id = _uuid.v4();

    try {
      await _db.into(_db.historyEntries).insert(
        HistoryEntriesCompanion.insert(
          id: id,
          url: cleanUrl,
          title: Value(cleanTitle),
          faviconUrl: Value(faviconUrl),
          visitedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final newModel = HistoryEntryModel(
        id: id,
        url: cleanUrl,
        title: cleanTitle,
        faviconUrl: faviconUrl,
        visitedAt: now,
      );

      // Deduplicate rapid subsequent visits to same URL within 60s
      final filteredState = state.where((e) {
        return e.url != cleanUrl || now.difference(e.visitedAt).inSeconds > 60;
      }).toList();

      state = [newModel, ...filteredState];
    } catch (_) {
      // Guard against concurrent access
    }
  }

  /// Delete a single entry.
  Future<void> deleteEntry(String id) async {
    await _db.deleteHistoryEntry(id);
    state = state.where((e) => e.id != id).toList();
  }

  /// Clear history by range: 'last_hour', 'today', 'all_time'.
  Future<void> clearHistoryByRange(String range) async {
    final now = DateTime.now();

    if (range == 'last_hour') {
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final entriesToDelete = state.where((e) => e.visitedAt.isAfter(oneHourAgo)).toList();
      for (final e in entriesToDelete) {
        await _db.deleteHistoryEntry(e.id);
      }
      state = state.where((e) => !e.visitedAt.isAfter(oneHourAgo)).toList();
    } else if (range == 'today') {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final entriesToDelete = state.where((e) => e.visitedAt.isAfter(startOfToday)).toList();
      for (final e in entriesToDelete) {
        await _db.deleteHistoryEntry(e.id);
      }
      state = state.where((e) => !e.visitedAt.isAfter(startOfToday)).toList();
    } else {
      // all_time
      await _db.clearAllHistory();
      state = [];
    }
  }

  /// Evaluates auto-clear policy on app exit or backgrounding.
  Future<void> evaluateAutoClearPolicy(String policy) async {
    final now = DateTime.now();
    switch (policy) {
      case 'on_app_exit':
        await clearHistoryByRange('all_time');
        break;
      case 'after_15m':
        final cutoff = now.subtract(const Duration(minutes: 15));
        final oldEntries = state.where((e) => e.visitedAt.isBefore(cutoff)).toList();
        for (final e in oldEntries) {
          await _db.deleteHistoryEntry(e.id);
        }
        state = state.where((e) => e.visitedAt.isAfter(cutoff)).toList();
        break;
      case 'after_1h':
        final cutoff = now.subtract(const Duration(hours: 1));
        final oldEntries = state.where((e) => e.visitedAt.isBefore(cutoff)).toList();
        for (final e in oldEntries) {
          await _db.deleteHistoryEntry(e.id);
        }
        state = state.where((e) => e.visitedAt.isAfter(cutoff)).toList();
        break;
      case 'after_1d':
        final cutoff = now.subtract(const Duration(days: 1));
        final oldEntries = state.where((e) => e.visitedAt.isBefore(cutoff)).toList();
        for (final e in oldEntries) {
          await _db.deleteHistoryEntry(e.id);
        }
        state = state.where((e) => e.visitedAt.isAfter(cutoff)).toList();
        break;
      case 'never':
      default:
        break;
    }
  }

  Future<void> clearAll() async {
    await _db.clearAllHistory();
    state = [];
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntryModel>>(
        HistoryNotifier.new);
