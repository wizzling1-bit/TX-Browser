import 'package:drift/drift.dart';

/// Key-value settings table.
///
/// Simple key-value store avoids a schema migration per new setting.
///
/// See TAD.md §5.

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
