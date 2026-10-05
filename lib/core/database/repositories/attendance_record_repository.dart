import 'package:drift/drift.dart';

import '../../../features/attendance/models/attendance_models.dart';
import '../database.dart';

class AttendanceRecordRepository {
  final AppDatabase db;

  AttendanceRecordRepository(this.db);

  Future<List<AttendanceRecord>> getAll() =>
      db.select(db.attendanceRecords).get();

  Future<List<AttendanceRecord>> forSession(int sessionId) => (db.select(
    db.attendanceRecords,
  )..where((t) => t.sessionId.equals(sessionId))).get();

  /// The record for this student in this session, if any.
  ///
  /// At most one can exist because of the unique index on
  /// (session_id, student_id), so a single-or-null read is exact rather than
  /// merely optimistic.
  Future<AttendanceRecord?> findForStudent(int sessionId, int studentId) {
    return (db.select(db.attendanceRecords)..where(
          (t) => t.sessionId.equals(sessionId) & t.studentId.equals(studentId),
        ))
        .getSingleOrNull();
  }

  /// The ids of every student with a record in this session.
  ///
  /// Drives the PRESENT/ABSENT split without loading whole rows.
  Future<Set<int>> presentStudentIds(int sessionId) async {
    final rows =
        await (db.selectOnly(db.attendanceRecords)
              ..addColumns([db.attendanceRecords.studentId])
              ..where(db.attendanceRecords.sessionId.equals(sessionId)))
            .get();
    return rows
        .map((row) => row.read(db.attendanceRecords.studentId))
        .whereType<int>()
        .toSet();
  }

  /// Marks a student present, or reports that they already were.
  ///
  /// Asks the database to decide with a single statement: `INSERT OR IGNORE
  /// ... RETURNING`, backed by the unique index on (session_id, student_id).
  /// A returned row means this call created it; no row means one was already
  /// there.
  ///
  /// A read-then-write version of this would have a gap between the two
  /// statements for a fast double scan to slip through. It also cannot use
  /// plain `insertOrIgnore`: that reports a stale row id rather than 0 when the
  /// insert is skipped, so a repeat scan would look like a new one.
  ///
  /// On conflict the existing row is returned untouched. In particular
  /// `scannedAt` is not rewritten, so a repeat scan reports the time the
  /// student actually arrived rather than the time the card was read again.
  Future<MarkPresentResult> markPresent({
    required int sessionId,
    required Student student,
    required String rawBarcode,
    required DateTime scannedAt,
  }) async {
    final inserted = await db
        .into(db.attendanceRecords)
        .insertReturningOrNull(
          AttendanceRecordsCompanion.insert(
            sessionId: sessionId,
            studentId: student.id,
            rollNoSnapshot: student.rollNo,
            nameSnapshot: student.name,
            institutionSnapshot: student.institution,
            boardingPointSnapshot: student.boardingPoint,
            status: AttendanceStatus.present.wireValue,
            scannedBarcode: rawBarcode,
            scannedAt: scannedAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );

    if (inserted != null) {
      return MarkPresentResult(record: inserted, isNew: true);
    }

    final existing = await findForStudent(sessionId, student.id);
    if (existing == null) {
      // insertOrIgnore can only skip on the unique index, so a row must exist.
      // If it somehow does not, fail loudly rather than dereferencing null.
      throw StateError(
        'Could not mark student ${student.id} present in session $sessionId: '
        'the insert was ignored but no existing record was found.',
      );
    }
    return MarkPresentResult(record: existing, isNew: false);
  }

  /// Removes this student's record for the session, undoing a mark.
  ///
  /// Absence is never stored: every row here is a PRESENT row, and both
  /// [presentStudentIds] and the report absentee query read "no row" as
  /// absent. So an undo has to delete rather than write an ABSENT row, or the
  /// student would count as present everywhere at once.
  ///
  /// Matching on (session_id, student_id) rather than a record id means a
  /// second scan cannot delete a newer mark: the row found is whichever one
  /// the unique index holds, which is the same one the UI displayed.
  ///
  /// Returns whether a row was actually deleted, so callers can tell a real
  /// undo from a no-op instead of assuming success.
  Future<bool> deleteForStudent(int sessionId, int studentId) async {
    final removed = await (db.delete(db.attendanceRecords)..where(
          (t) => t.sessionId.equals(sessionId) & t.studentId.equals(studentId),
        ))
        .go();
    return removed > 0;
  }

  Future<List<AttendanceRecord>> forStudent(int studentId) => (db.select(
    db.attendanceRecords,
  )..where((t) => t.studentId.equals(studentId))).get();

  Future<List<AttendanceRecord>> history({
    int? studentId,
    DateTime? from,
    DateTime? to,
  }) {
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
    return db
        .into(db.attendanceRecords)
        .insert(
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
