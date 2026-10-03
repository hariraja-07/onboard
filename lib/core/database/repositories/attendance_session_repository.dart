import 'package:drift/drift.dart';

import '../database.dart';
import '../../../features/attendance/models/attendance_models.dart';

class AttendanceSessionRepository {
  AttendanceSessionRepository(this._db);

  final AppDatabase _db;

  Future<int> createOpen({
    required DateTime attendanceDate,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final id = await _db
        .into(_db.attendanceSessions)
        .insert(
          AttendanceSessionsCompanion.insert(
            attendanceDate: DateTime(
              attendanceDate.year,
              attendanceDate.month,
              attendanceDate.day,
            ),
            status: 'open',
            createdAt: now,
          ),
        );
    return id;
  }

  Future<AttendanceSession?> findOpenForDate(DateTime attendanceDate) async {
    final start = DateTime(
      attendanceDate.year,
      attendanceDate.month,
      attendanceDate.day,
    );
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.attendanceSessions)
          ..where(
            (tbl) =>
                tbl.attendanceDate.isBiggerOrEqualValue(start) &
                tbl.attendanceDate.isSmallerThanValue(end) &
                tbl.status.equals('open'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<AttendanceSession>> forDate(DateTime attendanceDate) async {
    final start = DateTime(
      attendanceDate.year,
      attendanceDate.month,
      attendanceDate.day,
    );
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.attendanceSessions)
          ..where(
            (tbl) =>
                tbl.attendanceDate.isBiggerOrEqualValue(start) &
                tbl.attendanceDate.isSmallerThanValue(end),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<int> insert({
    required DateTime attendanceDate,
    required DateTime createdAt,
    required String status,
  }) async {
    return _db
        .into(_db.attendanceSessions)
        .insert(
          AttendanceSessionsCompanion.insert(
            attendanceDate: attendanceDate,
            status: status,
            createdAt: createdAt,
          ),
        );
  }

  Future<void> finishSession(int sessionId, {DateTime? endedAt}) async {
    await (_db.update(
      _db.attendanceSessions,
    )..where((tbl) => tbl.id.equals(sessionId))).write(
      AttendanceSessionsCompanion(
        status: const Value('completed'),
        endedAt: Value(endedAt ?? DateTime.now()),
      ),
    );
  }

  Future<List<AttendanceSessionSummary>> listSessions({
    DateTime? date,
    int limit = 200,
  }) async {
    final query = _db.select(_db.attendanceSessions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.attendanceDate),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);
    final sessions = await query.get();
    final results = <AttendanceSessionSummary>[];
    for (final s in sessions) {
      final rosterRows = await (_db.select(
        _db.attendanceSessionRoster,
      )..where((r) => r.sessionId.equals(s.id))).get();
      final recordRows = await (_db.select(
        _db.attendanceRecords,
      )..where((r) => r.sessionId.equals(s.id))).get();
      final total = rosterRows.length;
      final present = recordRows.length;
      final absent = total > present ? total - present : 0;
      final percent = total == 0 ? 0.0 : (present * 100.0 / total);
      results.add(
        AttendanceSessionSummary(
          sessionId: s.id,
          attendanceDate: s.attendanceDate,
          status: s.status == 'completed'
              ? AttendanceSessionStatus.completed
              : AttendanceSessionStatus.open,
          total: total,
          present: present,
          absent: absent,
          percent: percent,
          startedAt: s.createdAt,
          endedAt: s.endedAt,
        ),
      );
    }
    return results;
  }

  Future<void> complete(int sessionId, [DateTime? finishedAt]) async {
    await finishSession(sessionId, endedAt: finishedAt);
  }

  Future<AttendanceSession?> findById(int sessionId) async {
    return (_db.select(
      _db.attendanceSessions,
    )..where((tbl) => tbl.id.equals(sessionId))).getSingleOrNull();
  }
}
