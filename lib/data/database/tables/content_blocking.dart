import 'package:drift/drift.dart';

/// Exceptions table for Content Blocker / Tx Shield.
class ContentBlockerExceptions extends Table {
  TextColumn get host => text()();
  BoolColumn get isAllowed => boolean().withDefault(const Constant(true))(); // true = allowlist (disable shield for host), false = custom blocklist
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {host};
}
