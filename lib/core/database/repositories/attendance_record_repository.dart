import 'package:drift/drift.dart';

import '../../database/database.dart';

class AttendanceRecordRepository {
  final AppDatabase db;

  AttendanceRecordRepository(this.db);

  Future<List<AttendanceRecord>> getAll() => db.select(db.attendanceRecords).get();

  Future<List<AttendanceRecord>> forSession(int sessionId) =>
      (db.select(db.attendanceRecords)..where((t) => t.sessionId.equals(sessionId))).get();

  Future<List<AttendanceRecord>> forStudent(int studentId) =>
      (db.select(db.attendanceRecords)..where((t) => t.studentId.equals(studentId))).get();

  Future<List<AttendanceRecord>> history({int? studentId, DateTime? from, DateTime? to}) {
    var query = db.select(db.attendanceRecords);
    if (studentId != null) {
      query = query..where((t) => t.studentId.equals(studentId));
    }
    if (from != null) {
      query = query..where((t) => t.scannedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query = query..where((t) => t.scannedAt.isSmallerOrEqualValue(to));
    }
    return query.get();
  }

  Future<int> insert({
    required int sessionId,
    required int studentId,
    required String rollNoSnapshot,
    required String nameSnapshot,
    required String institutionSnapshot,
    required String boardingPointSnapshot,
    required String status,
    required String scannedBarcode,
    required DateTime scannedAt,
  }) {
    return db.into(db.attendanceRecords).insert(
          AttendanceRecordsCompanion(
            sessionId: Value(sessionId),
            studentId: Value(studentId),
            rollNoSnapshot: Value(rollNoSnapshot),
            nameSnapshot: Value(nameSnapshot),
            institutionSnapshot: Value(institutionSnapshot),
            boardingPointSnapshot: Value(boardingPointSnapshot),
            status: Value(status),
            scannedBarcode: Value(scannedBarcode),
            scannedAt: Value(scannedAt),
          ),
        );
  }

  Future<int> delete(int id) =>
      (db.delete(db.attendanceRecords)..where((t) => t.id.equals(id))).go();
}