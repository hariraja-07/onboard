import 'package:drift/drift.dart';

// Tables

class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get rollNo => text().withLength(min: 1, max: 50).unique()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get institution => text().withLength(min: 1, max: 150)();
  TextColumn get boardingPoint => text().withLength(min: 1, max: 150)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class AttendanceSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get attendanceDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get status => text().withLength(min: 1, max: 20)();
}

/// One record per student per session, enforced by SQLite.
///
/// Declared as a unique index rather than a `uniqueKeys` entry. `uniqueKeys`
/// emits an inline `UNIQUE(...)` inside `CREATE TABLE`, but SQLite cannot add a
/// table constraint to a table that already exists, so a migrated database
/// would end up with a standalone index while a fresh one had an inline
/// constraint — functionally equal but structurally different.
///
/// Relying on the database rather than a check-then-insert in Dart is what
/// stops a fast double scan of the same card from writing two rows.
@TableIndex(
  name: 'idx_attendance_records_session_student',
  columns: {#sessionId, #studentId},
  unique: true,
)
class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(AttendanceSessions, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  TextColumn get rollNoSnapshot => text().withLength(min: 1, max: 50)();
  TextColumn get nameSnapshot => text().withLength(min: 1, max: 100)();
  TextColumn get institutionSnapshot => text().withLength(min: 1, max: 150)();
  TextColumn get boardingPointSnapshot => text().withLength(min: 1, max: 150)();
  TextColumn get status => text().withLength(min: 1, max: 20)();
  TextColumn get scannedBarcode => text().withLength(min: 1, max: 100)();
  DateTimeColumn get scannedAt => dateTime()();
}