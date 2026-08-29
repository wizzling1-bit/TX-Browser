import '../../data/database/app_database.dart';

/// Reads and writes settings from the Drift settings table.
///
/// Thin layer over the database — the [SettingsNotifier] in the state
/// layer calls through to this for persistence.

class SettingsService {
  const SettingsService(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) => _db.getSetting(key);

  Future<void> set(String key, String value) => _db.setSetting(key, value);

  Future<void> delete(String key) => _db.deleteSetting(key);

  Stream<String?> watch(String key) => _db.watchSetting(key);
}
