import 'package:drift/drift.dart';

import '../database.dart';
import '../../../features/attendance/models/attendance_models.dart';

class AttendanceSessionRepository {
  AttendanceSessionRepository(this._db);

  final AppDatabase _db;

  Future<int> createOpen({
    required DateTime attendanceDate,
    String tripType = 'morning',
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
            tripType: Value(tripType),
            status: 'open',
            createdAt: now,
          ),
        );
    return id;
  }

  /// The most recent session still marked `open`, of any date.
  ///
  /// Used instead of [findOpenForDate] so a session left open across midnight
  /// (or a crash) is still surfaced, rather than silently lingering forever.
  Future<AttendanceSession?> findAnyOpen() async {
    return (_db.select(_db.attendanceSessions)
          ..where((t) => t.status.equals('open'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<AttendanceSession?> findOpenForDateAndTrip(
    DateTime attendanceDate,
    String tripType,
  ) async {
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
                tbl.tripType.equals(tripType) &
                tbl.status.equals('open'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns the open session if there is one for [attendanceDate] and [tripType],
  /// otherwise closes any stale open session and opens a new one.
  ///
  /// Runs in a transaction so two near-simultaneous starts cannot both insert:
  /// the first commits the open row, the second sees it. This keeps the
  /// invariant that at most one session is open at a time.
  Future<int> findOrCreateOpen({
    required DateTime attendanceDate,
    String tripType = 'morning',
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return _db.transaction(() async {
      final matching = await findOpenForDateAndTrip(attendanceDate, tripType);
      if (matching != null) return matching.id;

      final anyOpen = await findAnyOpen();
      if (anyOpen != null) {
        await complete(anyOpen.id);
      }

      return createOpen(
        attendanceDate: attendanceDate,
        tripType: tripType,
        createdAt: now,
      );
    });
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
    String tripType = 'morning',
  }) async {
    return _db
        .into(_db.attendanceSessions)
        .insert(
          AttendanceSessionsCompanion.insert(
            attendanceDate: attendanceDate,
            tripType: Value(tripType),
            status: status,
            createdAt: createdAt,
          ),
        );
  }

  Future<AttendanceSession?> findForDateAndTrip(
    DateTime attendanceDate,
    String tripType,
  ) async {
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
                tbl.tripType.equals(tripType),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(1))
        .getSingleOrNull();
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
    DateTime? from,
    DateTime? to,
    int? limit = 200,
  }) async {
    final query = _db.select(_db.attendanceSessions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.attendanceDate),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (from != null) {
      final start = DateTime(from.year, from.month, from.day);
      query.where((t) => t.attendanceDate.isBiggerOrEqualValue(start));
    }
    if (to != null) {
      final end = DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1));
      query.where((t) => t.attendanceDate.isSmallerThanValue(end));
    }
    if (limit != null) query.limit(limit);
    final sessions = await query.get();
    if (sessions.isEmpty) return const [];

    // Two grouped counts for the whole page instead of two queries per
    // session. At a 200-session page that is 3 reads rather than ~400.
    final ids = sessions.map((s) => s.id).toList();
    final rosterCounts = await _countBySession(
      'attendance_session_roster',
      ids,
    );
    final recordCounts = await _countBySession('attendance_records', ids);

    return [
      for (final s in sessions)
        _summarise(
          s,
          total: rosterCounts[s.id] ?? 0,
          present: recordCounts[s.id] ?? 0,
        ),
    ];
  }

  /// `{sessionId: rowCount}` for [table], restricted to [sessionIds].
  Future<Map<int, int>> _countBySession(
    String table,
    List<int> sessionIds,
  ) async {
    final placeholders = List.filled(sessionIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT session_id, COUNT(*) AS c FROM $table '
          'WHERE session_id IN ($placeholders) GROUP BY session_id',
          variables: [for (final id in sessionIds) Variable.withInt(id)],
        )
        .get();
    return {
      for (final row in rows) row.read<int>('session_id'): row.read<int>('c'),
    };
  }

  AttendanceSessionSummary _summarise(
    AttendanceSession s, {
    required int total,
    required int present,
  }) {
    final absent = total > present ? total - present : 0;
    final percent = total == 0 ? 0.0 : (present * 100.0 / total);
    return AttendanceSessionSummary(
      sessionId: s.id,
      attendanceDate: s.attendanceDate,
      tripType: s.tripType,
      status: s.status == 'completed'
          ? AttendanceSessionStatus.completed
          : AttendanceSessionStatus.open,
      total: total,
      present: present,
      absent: absent,
      percent: percent,
      startedAt: s.createdAt,
      endedAt: s.endedAt,
    );
  }

  Future<void> complete(int sessionId, [DateTime? finishedAt]) async {
    await finishSession(sessionId, endedAt: finishedAt);
  }

  Future<AttendanceSession?> findById(int sessionId) async {
    return (_db.select(
      _db.attendanceSessions,
    )..where((tbl) => tbl.id.equals(sessionId))).getSingleOrNull();
  }

  /// Deletes a session and its associated records and roster snapshot.
  Future<void> deleteSession(int id) {
    return _db.transaction(() async {
      await (_db.delete(_db.attendanceRecords)
            ..where((t) => t.sessionId.equals(id)))
          .go();
      await (_db.delete(_db.attendanceSessionRoster)
            ..where((t) => t.sessionId.equals(id)))
          .go();
      await (_db.delete(_db.attendanceSessions)
            ..where((t) => t.id.equals(id)))
          .go();
    });
  }
}
