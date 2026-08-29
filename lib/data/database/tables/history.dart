import 'package:drift/drift.dart';

/// Browsing history table.
///
/// No rows are ever written here for private tabs — enforced at the
/// service layer, not by a database constraint.
///
/// See TAD.md §5.

class HistoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get faviconUrl => text().nullable()();
  DateTimeColumn get visitedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
