import 'package:drift/drift.dart';

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

  Future<int> complete(int id, DateTime completedAt) {
    return (db.update(db.attendanceSessions)..where((t) => t.id.equals(id))).write(
      AttendanceSessionsCompanion(
        completedAt: Value(completedAt),
        status: Value('completed'),
      ),
    );
  }

  Future<int> delete(int id) =>
      (db.delete(db.attendanceSessions)..where((t) => t.id.equals(id))).go();
}