import 'package:drift/drift.dart';

/// Tab groups table for spatial tab organization.
class TabGroups extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF609966))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
