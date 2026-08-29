import 'package:drift/drift.dart';

/// Open tabs table.
///
/// Stores the state of each open browser tab for session restore.
/// Private tabs are persisted transiently (in case OS kills the app)
/// but purged on next cold start.
///
/// See TAD.md §5.

class Tabs extends Table {
  TextColumn get id => text()();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get faviconUrl => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  TextColumn get groupId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
