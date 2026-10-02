import 'package:drift/drift.dart';

import '../../../features/attendance/models/attendance_models.dart';
import '../database.dart';

class AttendanceSessionRepository {
  final AppDatabase db;

  AttendanceSessionRepository(this.db);

  Future<List<AttendanceSession>> getAll() => db.select(db.attendanceSessions).get();

  Future<AttendanceSession?> findById(int id) =>
      (db.select(db.attendanceSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<AttendanceSession>> forDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.attendanceSessions)
          ..where((t) => t.attendanceDate.isBetweenValues(start, end)))
        .get();
  }

  Future<int> insert({
    required DateTime attendanceDate,
    required DateTime createdAt,
    required String status,
  }) {
    return db.into(db.attendanceSessions).insert(
          AttendanceSessionsCompanion(
            attendanceDate: Value(attendanceDate),
            createdAt: Value(createdAt),
            status: Value(status),
          ),
        );
  }

  /// Starts a session for a date.
  Future<int> createOpen({
    required DateTime attendanceDate,
    required DateTime createdAt,
  }) {
    return insert(
      attendanceDate: attendanceDate,
      createdAt: createdAt,
      status: AttendanceSessionStatus.open.wireValue,
    );
  }

  /// The open session for a date, or null if none is in progress.
  ///
  /// Lets an interrupted session be picked back up rather than being lost to an
  /// accidental close. Takes the most recent match rather than a single-or-null
  /// read, so a duplicate left behind by an earlier version cannot throw.
  Future<AttendanceSession?> findOpenForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final matches = await (db.select(db.attendanceSessions)
          ..where((t) =>
              t.attendanceDate.isBetweenValues(start, end) &
              t.status.equals(AttendanceSessionStatus.open.wireValue))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return matches.isEmpty ? null : matches.first;
  }

  Future<int> complete(int id, DateTime completedAt) {
    return (db.update(db.attendanceSessions)..where((t) => t.id.equals(id))).write(
      AttendanceSessionsCompanion(
        completedAt: Value(completedAt),
        status: Value(AttendanceSessionStatus.completed.wireValue),
      ),
    );
  }

  Future<int> delete(int id) =>
      (db.delete(db.attendanceSessions)..where((t) => t.id.equals(id))).go();
}