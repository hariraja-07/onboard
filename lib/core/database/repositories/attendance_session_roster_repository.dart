import 'package:drift/drift.dart';

import '../database.dart';

class AttendanceSessionRosterRepository {
  AttendanceSessionRosterRepository(this._db);

  final AppDatabase _db;

  Future<void> insertRoster(
    int sessionId,
    List<Student> students, {
    DateTime? createdAt,
  }) async {
    if (students.isEmpty) return;
    final now = createdAt ?? DateTime.now();
    await _db.batch((batch) {
      for (final s in students) {
        batch.insert(
          _db.attendanceSessionRoster,
          AttendanceSessionRosterCompanion.insert(
            sessionId: sessionId,
            studentId: s.id,
            rollNo: s.rollNo,
            name: s.name,
            institution: s.institution,
            boardingPoint: s.boardingPoint,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<List<AttendanceSessionRosterData>> getRoster(int sessionId) async {
    final query = _db.select(_db.attendanceSessionRoster)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.asc(t.rollNo)]);
    return query.get();
  }
}
