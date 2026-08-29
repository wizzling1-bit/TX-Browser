import 'package:drift/drift.dart';

/// Site permissions table for per-host permission controls.
class SitePermissions extends Table {
  TextColumn get id => text()();
  TextColumn get host => text()();
  TextColumn get permissionType => text()(); // camera, microphone, location, notifications, downloads
  TextColumn get state => text()(); // granted, denied, ask
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
