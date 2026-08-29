import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';

/// Singleton provider for the Drift database.
///
/// Accessed by all service/state providers that need DB access.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
