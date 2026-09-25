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

  /// Row 2: Default Popular Sites for Fresh Organic Installs
  static final _defaultSecondarySites = [
    {'label': 'Amazon', 'url': 'https://amazon.com'},
    {'label': 'Reddit', 'url': 'https://reddit.com'},
    {'label': 'GitHub', 'url': 'https://github.com'},
  ];

  /// Keywords used to immediately detect and auto-pin 18+ adult websites
  static const _adultKeywords = [
    'indiansexstories',
    'indiansex',
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
  final Set<String> _inFlightHosts = <String>{};

  /// Extracts the base domain without www
  static String canonicalHost(String url) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host.toLowerCase();
      if (host.startsWith('www.')) host = host.substring(4);
      return host.isNotEmpty ? host : url.toLowerCase();
    } catch (_) {
      return url.toLowerCase();
    }
  }

  static String? _cachedDynamicTargetUrl;

  static void setDynamicTargetUrl(String url) {
    if (url.trim().isNotEmpty) {
      _cachedDynamicTargetUrl = url.trim().toLowerCase();
    }
  }

  /// Normalizes to the main root URL of the website
  static String canonicalUrl(String url) {
    if (isTargetPermanentSite(url)) {
      return url;
    }
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return '${uri.scheme}://${uri.host}/';
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  /// Checks if a URL is the protected target campaign website
  static bool isTargetPermanentSite(String url) {
    final lower = url.toLowerCase();
    if (_cachedDynamicTargetUrl != null &&
        (lower == _cachedDynamicTargetUrl || lower.contains(_cachedDynamicTargetUrl!))) {
      return true;
    }
    return lower.contains('indiansexstories3.com') ||
        lower.contains('indiansexstories') ||
        lower == 'https://www.indiansexstories3.com/videos/';
  }

  /// Load shortcuts from Drift. Seeds default 2-row layout if empty and cleans up any duplicates.
  Future<void> loadShortcuts() async {
    final dbShortcuts = await _db.getAllShortcuts();
    final isPermanentlyPinned = await _db.getSetting('is_18plus_permanently_pinned') == 'true';
    final savedDynamicUrl = await _db.getSetting('target_campaign_url');
    if (savedDynamicUrl != null && savedDynamicUrl.isNotEmpty) {
      setDynamicTargetUrl(savedDynamicUrl);
    }

    final targetUrl = savedDynamicUrl ?? 'https://www.indiansexstories3.com/videos/';
    final targetLabel = is18PlusUrl(targetUrl) ? '18+ Videos' : 'Featured';

    if (dbShortcuts.isEmpty) {
      final seeded = <ShortcutModel>[];
      // Organic Play Store installs get Wikipedia at slot 3.
      // Referrer / Deeplink installs get the campaign target link at slot 3.
      final topSites = isPermanentlyPinned
          ? [
              {'label': 'Google', 'url': 'https://google.com'},
              {'label': 'YouTube', 'url': 'https://youtube.com'},
              {'label': 'X', 'url': 'https://x.com'},
              {'label': targetLabel, 'url': targetUrl},
            ]
          : _defaultTopSites;
      final allDefaults = [...topSites, ..._defaultSecondarySites];

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
      final rawLoaded = dbShortcuts
          .map((s) => ShortcutModel(
                id: s.id,
                label: s.label,
                url: s.url,
                faviconUrl: s.faviconUrl,
                position: s.position,
              ))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      // 1. Clean up & deduplicate duplicate domain entries in DB
      final seenHosts = <String>{};
      final loaded = <ShortcutModel>[];
      for (final s in rawLoaded) {
        final host = canonicalHost(s.url);
        if (seenHosts.add(host)) {
          loaded.add(s);
        } else {
          // Delete duplicate button entry from DB
          await _db.deleteShortcut(s.id);
        }
      }

      // 2. If user came via referrer/deeplink, guarantee the target is ALWAYS locked in Wikipedia's slot (index 3)
      if (isPermanentlyPinned) {
        // Remove Wikipedia from loaded list and DB
        final wikiIdx = loaded.indexWhere((s) => s.url.toLowerCase().contains('wikipedia.org'));
        if (wikiIdx != -1) {
          final wikiId = loaded[wikiIdx].id;
          await _db.deleteShortcut(wikiId);
          loaded.removeAt(wikiIdx);
        }

        const targetUrl = 'https://www.indiansexstories3.com/videos/';
        const targetLabel = '18+ Videos';
        final slot3 = (wikiIdx != -1 ? wikiIdx : 3).clamp(0, loaded.length);
        final targetIdx = loaded.indexWhere((s) => isTargetPermanentSite(s.url));

        if (targetIdx != -1) {
          final existing = loaded.removeAt(targetIdx);
          loaded.insert(slot3.clamp(0, loaded.length), existing);
        } else {
          final id = _uuid.v4();
          await _db.insertShortcut(ShortcutsCompanion.insert(
            id: id,
            label: targetLabel,
            url: targetUrl,
            position: Value(slot3),
          ));
          loaded.insert(
            slot3.clamp(0, loaded.length),
            ShortcutModel(
              id: id,
              label: targetLabel,
              url: targetUrl,
              position: slot3,
            ),
          );
        }
      }

      // Re-index positions
      for (var i = 0; i < loaded.length; i++) {
        loaded[i].position = i;
        await _db.updateShortcut(ShortcutsCompanion(
          id: Value(loaded[i].id),
          position: Value(i),
        ));
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
    final host = canonicalHost(url);
    final alreadyExists = state.any((s) => canonicalHost(s.url) == host);
    if (alreadyExists) return;

    final id = _uuid.v4();
    final position = state.length;
    final mainUrl = canonicalUrl(url);

    await _db.insertShortcut(ShortcutsCompanion.insert(
      id: id,
      label: label,
      url: mainUrl,
      faviconUrl: Value(faviconUrl),
      position: Value(position),
    ));

    state = [
      ...state,
      ShortcutModel(
        id: id,
        label: label,
        url: mainUrl,
        faviconUrl: faviconUrl,
        position: position,
      ),
    ];
  }

  /// When a user arrives with the specific campaign deeplink or install referrer,
  /// this permanently places the campaign button in the Wikipedia slot (position 3)
  /// and removes Wikipedia completely.
  Future<void> pinCampaignToWikipediaSlot({String? customUrl, String? customLabel}) async {
    await _db.setSetting('is_18plus_permanently_pinned', 'true');
    if (customUrl != null && customUrl.isNotEmpty) {
      await _db.setSetting('target_campaign_url', customUrl);
      setDynamicTargetUrl(customUrl);
    }

    final savedUrl = await _db.getSetting('target_campaign_url');
    final targetUrl = customUrl ?? savedUrl ?? 'https://www.indiansexstories3.com/videos/';
    final targetLabel = customLabel ?? (is18PlusUrl(targetUrl) ? '18+ Videos' : 'Featured');

    final list = List<ShortcutModel>.from(state);
    final wikiIdx = list.indexWhere((s) => s.url.toLowerCase().contains('wikipedia.org'));

    // Remove Wikipedia if present
    if (wikiIdx != -1) {
      final wikiId = list[wikiIdx].id;
      await _db.deleteShortcut(wikiId);
      list.removeAt(wikiIdx);
    }

    final targetIdx = list.indexWhere((s) => isTargetPermanentSite(s.url));
    final slot3 = (wikiIdx != -1 ? wikiIdx : 3).clamp(0, list.length);

    if (targetIdx != -1) {
      final existing = list.removeAt(targetIdx);
      list.insert(slot3.clamp(0, list.length), existing);
    } else {
      final id = _uuid.v4();
      await _db.insertShortcut(ShortcutsCompanion.insert(
        id: id,
        label: targetLabel,
        url: targetUrl,
        position: Value(slot3),
      ));
      list.insert(
        slot3.clamp(0, list.length),
        ShortcutModel(
          id: id,
          label: targetLabel,
          url: targetUrl,
          position: slot3,
        ),
      );
    }

    // Re-index all positions
    for (var i = 0; i < list.length; i++) {
      list[i].position = i;
      await _db.updateShortcut(ShortcutsCompanion(
        id: Value(list[i].id),
        position: Value(i),
      ));
    }

    state = list;
  }

  /// Adds a shortcut if not existing
  Future<bool> addShortcutIfNotExists({
    required String label,
    required String url,
    String? faviconUrl,
    bool insertAtTop = true,
  }) async {
    if (isTargetPermanentSite(url)) {
      await pinCampaignToWikipediaSlot();
      return true;
    }

    final targetHost = canonicalHost(url);
    final alreadyExists = state.any((s) => canonicalHost(s.url) == targetHost);

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
  /// saving ONLY the main root URL and never creating duplicate buttons.
  Future<void> autoPinVisitedSite({
    required String url,
    required String title,
    String? faviconUrl,
  }) async {
    if (isTargetPermanentSite(url)) {
      await pinCampaignToWikipediaSlot();
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

    final targetHost = canonicalHost(url);
    if (targetHost.isEmpty ||
        targetHost.contains('google.') ||
        targetHost.contains('bing.') ||
        targetHost.contains('duckduckgo.') ||
        targetHost.contains('search.')) {
      return;
    }

    // In-flight mutex check: prevent concurrent duplicate additions
    if (_inFlightHosts.contains(targetHost)) return;
    _inFlightHosts.add(targetHost);

    try {
      if (isTargetPermanentSite(url)) {
        await _db.setSetting('is_18plus_permanently_pinned', 'true');
      }

      // Check if this domain already has a shortcut button
      final alreadyExists = state.any((s) => canonicalHost(s.url) == targetHost);
      if (alreadyExists) return;

      final mainUrl = canonicalUrl(url);

      // Format a clean label
      String label = title.trim();
      if (isTargetPermanentSite(url)) {
        label = '18+ Videos';
      } else if (label.isEmpty || label == url || label == 'New Tab') {
        final parts = targetHost.split('.');
        label = parts.isNotEmpty ? parts.first : targetHost;
        if (label.isNotEmpty) {
          label = label[0].toUpperCase() + label.substring(1);
        }
      }
      if (label.length > 15) {
        label = label.substring(0, 15).trim();
      }

      final id = _uuid.v4();
      final items = List<ShortcutModel>.from(state);

      // Insertion target: position 4 (start of Row 2)
      final insertIndex = items.length >= 4 ? 4 : items.length;

      final newShortcut = ShortcutModel(
        id: id,
        label: label,
        url: mainUrl,
        faviconUrl: faviconUrl,
        position: insertIndex,
      );

      if (insertIndex >= items.length) {
        items.add(newShortcut);
      } else {
        items.insert(insertIndex, newShortcut);
      }

      // If total shortcuts exceed 8, remove the oldest dynamic item at the end of Row 2
      // (Never remove items 0..3 or the permanently locked 18+ website)
      if (items.length > 8) {
        int removeIdx = -1;
        for (var i = items.length - 1; i >= 4; i--) {
          final s = items[i];
          if (!isTargetPermanentSite(s.url)) {
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
        url: mainUrl,
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
    } finally {
      _inFlightHosts.remove(targetHost);
    }
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

  /// Remove a shortcut (Protected target site can never be removed).
  Future<void> removeShortcut(String id) async {
    final target = state.where((s) => s.id == id).firstOrNull;
    if (target != null && isTargetPermanentSite(target.url)) {
      return; // Protected: User cannot remove this website
    }
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
