import 'package:drift/drift.dart';

/// Shortcuts (pinned sites) table for the Home screen bento grid.
///
/// See TAD.md §5.

class Shortcuts extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get url => text()();
  TextColumn get faviconUrl => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
