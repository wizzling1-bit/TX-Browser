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

  static final _defaultShortcuts = [
    {'label': 'Google', 'url': 'https://google.com'},
    {'label': 'YouTube', 'url': 'https://youtube.com'},
    {'label': 'X', 'url': 'https://x.com'},
    {'label': 'Wikipedia', 'url': 'https://wikipedia.org'},
    {'label': 'Reddit', 'url': 'https://reddit.com'},
    {'label': 'GitHub', 'url': 'https://github.com'},
    {'label': 'Dribbble', 'url': 'https://dribbble.com'},
  ];

  @override
  List<ShortcutModel> build() {
    return [];
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Load shortcuts from Drift. Seeds default shortcuts if empty.
  Future<void> loadShortcuts() async {
    final dbShortcuts = await _db.getAllShortcuts();
    if (dbShortcuts.isEmpty) {
      final seeded = <ShortcutModel>[];
      for (var i = 0; i < _defaultShortcuts.length; i++) {
        final item = _defaultShortcuts[i];
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
      state = dbShortcuts
          .map((s) => ShortcutModel(
                id: s.id,
                label: s.label,
                url: s.url,
                faviconUrl: s.faviconUrl,
                position: s.position,
              ))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    }
  }

  /// Add a new shortcut.
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

  /// Adds a shortcut at the top (position 0) if a shortcut with the same domain or exact URL does not already exist.
  Future<bool> addShortcutIfNotExists({
    required String label,
    required String url,
    String? faviconUrl,
    bool insertAtTop = true,
  }) async {
    final targetHost =
        Uri.tryParse(url)?.host.toLowerCase().replaceAll('www.', '') ??
            url.toLowerCase();

    // Check if domain or exact URL already exists in shortcuts
    final alreadyExists = state.any((s) {
      final existingHost = Uri.tryParse(s.url)
              ?.host
              .toLowerCase()
              .replaceAll('www.', '') ??
          s.url.toLowerCase();
      return existingHost == targetHost ||
          s.url.toLowerCase() == url.toLowerCase();
    });

    if (alreadyExists) {
      return false;
    }

    if (insertAtTop) {
      final id = _uuid.v4();
      final newShortcut = ShortcutModel(
        id: id,
        label: label,
        url: url,
        faviconUrl: faviconUrl,
        position: 0,
      );

      // Shift existing shortcuts down by 1 position
      for (var i = 0; i < state.length; i++) {
        final existing = state[i];
        existing.position = i + 1;
        await _db.updateShortcut(ShortcutsCompanion(
          id: Value(existing.id),
          position: Value(existing.position),
        ));
      }

      await _db.insertShortcut(ShortcutsCompanion.insert(
        id: id,
        label: label,
        url: url,
        faviconUrl: Value(faviconUrl),
        position: const Value(0),
      ));

      state = [newShortcut, ...state];
      return true;
    }

    await addShortcut(
      label: label,
      url: url,
      faviconUrl: faviconUrl,
    );
    return true;
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
