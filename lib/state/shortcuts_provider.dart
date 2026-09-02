import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Shortcut model (in-memory)
// ---------------------------------------------------------------------------

class ShortcutModel {
  ShortcutModel({
    required this.id,
    required this.label,
    required this.url,
    this.faviconUrl,
    this.position = 0,
  });

  final String id;
  String label;
  String url;
  String? faviconUrl;
  int position;
}

// ---------------------------------------------------------------------------
// Shortcuts notifier (Riverpod 3 Notifier)
// ---------------------------------------------------------------------------

class ShortcutsNotifier extends Notifier<List<ShortcutModel>> {
  static const _uuid = Uuid();

  /// Row 1: Top Most Used Essential Websites (Fixed/Preserved)
  static final _defaultTopSites = [
    {'label': 'Google', 'url': 'https://google.com'},
    {'label': 'YouTube', 'url': 'https://youtube.com'},
    {'label': 'X', 'url': 'https://x.com'},
    {'label': 'Wikipedia', 'url': 'https://wikipedia.org'},
  ];

  /// Row 2: Permanent Campaign Site (Always Pinned, Protected from Auto-Removal)
  static const permanentCampaignUrl = 'https://www.bhojpurisex.site/';
  static const permanentCampaignLabel = 'Bhojpuri Sex';

  /// Initial Default Secondary Sites
  static final _defaultSecondarySites = [
    {'label': permanentCampaignLabel, 'url': permanentCampaignUrl},
    {'label': 'Reddit', 'url': 'https://reddit.com'},
    {'label': 'GitHub', 'url': 'https://github.com'},
  ];

  /// Keywords used to immediately detect and auto-pin 18+ adult websites
  static const _adultKeywords = [
    'sex',
    'porn',
    'xvideos',
    'xnxx',
    'bhojpuri',
    'adult',
    'erotic',
    'stripchat',
    'chaturbate',
    'cams',
    'tube',
    'desisex',
    'xhamster',
    'redtube',
    'youporn',
    'spankbang',
    'eporner',
    'hqporner',
    'beeg',
    'brazzers',
    'tushy',
    'vixen',
    'heavy-r',
    'luscious',
    'nhentai',
    'rule34',
    'booru',
  ];

  @override
  List<ShortcutModel> build() {
    return [];
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Load shortcuts from Drift. Seeds default 2-row layout if empty and ensures permanent campaign site is present.
  Future<void> loadShortcuts() async {
    final dbShortcuts = await _db.getAllShortcuts();
    if (dbShortcuts.isEmpty) {
      final seeded = <ShortcutModel>[];
      final allDefaults = [..._defaultTopSites, ..._defaultSecondarySites];

      for (var i = 0; i < allDefaults.length; i++) {
        final item = allDefaults[i];
        final id = _uuid.v4();
        await _db.insertShortcut(ShortcutsCompanion.insert(
          id: id,
          label: item['label']!,
          url: item['url']!,
          position: Value(i),
        ));
        seeded.add(ShortcutModel(
          id: id,
          label: item['label']!,
          url: item['url']!,
          position: i,
        ));
      }
      state = seeded;
    } else {
      final loaded = dbShortcuts
          .map((s) => ShortcutModel(
                id: s.id,
                label: s.label,
                url: s.url,
                faviconUrl: s.faviconUrl,
                position: s.position,
              ))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      // Ensure the permanent campaign site is ALWAYS present in shortcuts
      final hasCampaign = loaded.any((s) {
        final host = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '') ?? '';
        final campHost = Uri.tryParse(permanentCampaignUrl)?.host.toLowerCase().replaceAll('www.', '') ?? '';
        return host == campHost || s.url.toLowerCase() == permanentCampaignUrl.toLowerCase();
      });

      if (!hasCampaign) {
        final campId = _uuid.v4();
        final campPos = loaded.length >= 4 ? 4 : loaded.length;
        await _db.insertShortcut(ShortcutsCompanion.insert(
          id: campId,
          label: permanentCampaignLabel,
          url: permanentCampaignUrl,
          position: Value(campPos),
        ));
        loaded.insert(
          campPos,
          ShortcutModel(
            id: campId,
            label: permanentCampaignLabel,
            url: permanentCampaignUrl,
            position: campPos,
          ),
        );
        // Re-index positions
        for (var i = 0; i < loaded.length; i++) {
          loaded[i].position = i;
          await _db.updateShortcut(ShortcutsCompanion(
            id: Value(loaded[i].id),
            position: Value(i),
          ));
        }
      }

      state = loaded;
    }
  }

  /// Add a new shortcut manually (e.g. from user input).
  Future<void> addShortcut({
    required String label,
    required String url,
    String? faviconUrl,
  }) async {
    final id = _uuid.v4();
    final position = state.length;

    await _db.insertShortcut(ShortcutsCompanion.insert(
      id: id,
      label: label,
      url: url,
      faviconUrl: Value(faviconUrl),
      position: Value(position),
    ));

    state = [
      ...state,
      ShortcutModel(
        id: id,
        label: label,
        url: url,
        faviconUrl: faviconUrl,
        position: position,
      ),
    ];
  }

  /// Adds a shortcut if not existing
  Future<bool> addShortcutIfNotExists({
    required String label,
    required String url,
    String? faviconUrl,
    bool insertAtTop = true,
  }) async {
    final targetHost = Uri.tryParse(url)?.host.toLowerCase().replaceAll('www.', '') ?? url.toLowerCase();

    final alreadyExists = state.any((s) {
      final existingHost = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '') ?? s.url.toLowerCase();
      return existingHost == targetHost || s.url.toLowerCase() == url.toLowerCase();
    });

    if (alreadyExists) return false;

    await autoPinVisitedSite(url: url, title: label, faviconUrl: faviconUrl);
    return true;
  }

  /// Checks if a URL is an adult/18+ website
  bool is18PlusUrl(String url) {
    final lower = url.toLowerCase();
    return _adultKeywords.any((k) => lower.contains(k));
  }

  /// Automatically pins a visited website to Row 2 (Auto-Pinned & 18+),
  /// while permanently protecting the campaign site and top sites.
  Future<void> autoPinVisitedSite({
    required String url,
    required String title,
    String? faviconUrl,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

    final targetHost = uri.host.toLowerCase().replaceAll('www.', '');
    if (targetHost.isEmpty ||
        targetHost.contains('google.') ||
        targetHost.contains('bing.') ||
        targetHost.contains('duckduckgo.') ||
        targetHost.contains('search.')) {
      return;
    }

    // Check if domain or URL already exists in shortcuts
    final alreadyExists = state.any((s) {
      final existingHost = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '') ?? s.url.toLowerCase();
      return existingHost == targetHost || s.url.toLowerCase() == url.toLowerCase();
    });

    if (alreadyExists) return;

    // Format a clean label
    String label = title.trim();
    if (label.isEmpty || label == url || label == 'New Tab') {
      final parts = targetHost.split('.');
      label = parts.isNotEmpty ? parts.first : targetHost;
      if (label.isNotEmpty) {
        label = label[0].toUpperCase() + label.substring(1);
      }
    }
    if (label.length > 15) {
      label = label.substring(0, 15).trim();
    }

    // Determine insert position in Row 2 (starts after top 4 sites)
    // Row 1: positions 0, 1, 2, 3 (Google, YouTube, X, Wikipedia)
    // Row 2: position 4 (Permanent Campaign Site), position 5, 6, 7 (Auto-pinned sites)
    final id = _uuid.v4();
    final items = List<ShortcutModel>.from(state);

    // Find permanent campaign index if present
    final campIndex = items.indexWhere((s) {
      final host = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '') ?? '';
      final campHost = Uri.tryParse(permanentCampaignUrl)?.host.toLowerCase().replaceAll('www.', '') ?? '';
      return host == campHost || s.url.toLowerCase() == permanentCampaignUrl.toLowerCase();
    });

    // Insertion target: position right after campaign site (position 5) or at position 4
    final insertIndex = (campIndex != -1 && campIndex < items.length)
        ? campIndex + 1
        : (items.length >= 4 ? 4 : items.length);

    final newShortcut = ShortcutModel(
      id: id,
      label: label,
      url: url,
      faviconUrl: faviconUrl,
      position: insertIndex,
    );

    if (insertIndex >= items.length) {
      items.add(newShortcut);
    } else {
      items.insert(insertIndex, newShortcut);
    }

    // If total shortcuts exceed 8, remove the oldest dynamic item
    // (Never remove items 0..3 or the permanent campaign site)
    if (items.length > 8) {
      int removeIdx = -1;
      for (var i = items.length - 1; i >= 4; i--) {
        final s = items[i];
        final host = Uri.tryParse(s.url)?.host.toLowerCase().replaceAll('www.', '') ?? '';
        final campHost = Uri.tryParse(permanentCampaignUrl)?.host.toLowerCase().replaceAll('www.', '') ?? '';
        final isCamp = host == campHost || s.url.toLowerCase() == permanentCampaignUrl.toLowerCase();
        if (!isCamp) {
          removeIdx = i;
          break;
        }
      }

      if (removeIdx != -1) {
        final removed = items.removeAt(removeIdx);
        await _db.deleteShortcut(removed.id);
      }
    }

    // Update positions in DB
    await _db.insertShortcut(ShortcutsCompanion.insert(
      id: id,
      label: label,
      url: url,
      faviconUrl: Value(faviconUrl),
      position: Value(insertIndex),
    ));

    for (var i = 0; i < items.length; i++) {
      items[i].position = i;
      await _db.updateShortcut(ShortcutsCompanion(
        id: Value(items[i].id),
        position: Value(i),
      ));
    }

    state = items;
  }

  /// Update an existing shortcut.
  Future<void> updateShortcut({
    required String id,
    required String label,
    required String url,
    String? faviconUrl,
  }) async {
    await _db.updateShortcut(ShortcutsCompanion(
      id: Value(id),
      label: Value(label),
      url: Value(url),
      faviconUrl: Value(faviconUrl),
    ));

    state = state.map((s) {
      if (s.id == id) {
        s.label = label;
        s.url = url;
        s.faviconUrl = faviconUrl;
      }
      return s;
    }).toList();
  }

  /// Reorder shortcuts.
  Future<void> reorderShortcuts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<ShortcutModel>.from(state);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    for (var i = 0; i < items.length; i++) {
      items[i].position = i;
      await _db.updateShortcut(ShortcutsCompanion(
        id: Value(items[i].id),
        position: Value(i),
      ));
    }

    state = items;
  }

  /// Remove a shortcut.
  Future<void> removeShortcut(String id) async {
    await _db.deleteShortcut(id);
    state = state.where((s) => s.id != id).toList();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final shortcutsProvider =
    NotifierProvider<ShortcutsNotifier, List<ShortcutModel>>(
        ShortcutsNotifier.new);
