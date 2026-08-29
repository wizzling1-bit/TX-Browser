import 'package:drift/drift.dart';

/// Downloads table.
///
/// Tracks file downloads with progress, status, and file metadata.
///
/// See TAD.md §5.

class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text().withDefault(const Constant('application/octet-stream'))();
  TextColumn get sourceUrl => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get progressPercent => integer().withDefault(const Constant(0))();
  /// Native Android DownloadManager ID for polling live progress.
  IntColumn get androidDownloadId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
