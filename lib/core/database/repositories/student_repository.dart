import 'package:drift/drift.dart';

import '../database.dart';

class StudentRepository {
  final AppDatabase db;

  StudentRepository(this.db);

  Future<List<Student>> getAll() => db.select(db.students).get();

  Future<Student?> findById(int id) =>
      (db.select(db.students)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Student?> findByRollNo(String rollNo) => (db.select(
    db.students,
  )..where((t) => t.rollNo.equals(rollNo))).getSingleOrNull();

  Future<List<Student>> search(String query) {
    final pattern = '%$query%';
    return (db.select(
      db.students,
    )..where((t) => t.name.like(pattern) | t.rollNo.like(pattern))).get();
  }

  Future<int> insert({
    required String rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
  }) {
    final now = DateTime.now();
    return db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            rollNo: rollNo,
            name: name,
            institution: institution,
            boardingPoint: boardingPoint,
            createdAt: now,
          ),
        );
  }

  /// Inserts many students in a single transaction.
  ///
  /// Either every row lands or none does, so a failure part-way through a large
  /// import cannot leave a half-imported roster behind.
  Future<void> insertAll(List<StudentsCompanion> entries) {
    return db.batch((batch) => batch.insertAll(db.students, entries));
  }

  /// Every roll number currently stored, used to spot students an Excel import
  /// would otherwise duplicate. Returns values as stored.
  Future<List<String>> allRollNos() async {
    final query = db.selectOnly(db.students)..addColumns([db.students.rollNo]);
    final rows = await query.get();
    return rows.map((row) => row.read(db.students.rollNo) ?? '').toList();
  }

  Future<int> update({
    required int id,
    String? rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
  }) {
    final now = DateTime.now();
    return (db.update(db.students)..where((t) => t.id.equals(id))).write(
      StudentsCompanion(
        rollNo: rollNo == null ? const Value.absent() : Value(rollNo),
        name: Value(name),
        institution: Value(institution),
        boardingPoint: Value(boardingPoint),
        updatedAt: Value(now),
      ),
    );
  }

  /// Deletes a student together with every attendance record that references
  /// them.
  ///
  /// Both tables are touched in one transaction: a student can never be left
  /// behind with their records already gone, nor records left pointing at a
  /// student who no longer exists. Historical roster snapshots are deliberately
  /// untouched, so past sessions keep the names they were taken with.
  Future<void> delete(int id) {
    return db.transaction(() async {
      await (db.delete(
        db.attendanceRecords,
      )..where((t) => t.studentId.equals(id))).go();
      await (db.delete(db.students)..where((t) => t.id.equals(id))).go();
    });
  }
}
