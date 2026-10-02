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