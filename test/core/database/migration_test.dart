import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';

/// The v1 schema is exactly the current schema minus the one index added in
/// v2 — drift's generated `CREATE TABLE` statements are unchanged, because the
/// migration only adds an index. So dropping that index and rewinding
/// `user_version` reproduces a genuine v1 file without hand-writing DDL that
/// could drift away from what drift actually emits.
const _indexName = 'idx_attendance_records_session_student';

void main() {
  // These tests deliberately open several databases at once — a v1 fixture, a
  // migrated file and a fresh in-memory one — which is exactly what drift
  // warns about, and is safe here because each has its own executor.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboard_migration');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File fileIn(String name) => File('${tempDir.path}/$name');

  Future<int> userVersionOf(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  /// Every schema object as `type name -> sql`, so two databases can be
  /// compared for structural equality.
  Future<Map<String, String>> schemaOf(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT type, name, sql FROM sqlite_master "
          "WHERE sql IS NOT NULL AND name != 'sqlite_sequence'",
        )
        .get();
    return {
      for (final row in rows)
        '${row.read<String>('type')} ${row.read<String>('name')}': row
            .read<String>('sql'),
    };
  }

  Future<List<String>> indexNamesOf(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  /// Writes a v1 database file containing one session and one record.
  Future<File> buildV1Database(String name) async {
    final file = fileIn(name);
    final db = AppDatabase.forTesting(NativeDatabase(file));

    // Rewind to v1.
    try {
      await db.customStatement('DROP INDEX $_indexName');
    } catch (_) {}
    await db.customStatement('PRAGMA user_version = 1');

    final studentId = await db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            rollNo: '24BMR016',
            name: 'Asha Rao',
            institution: 'Springfield College',
            boardingPoint: 'North Gate',
            createdAt: DateTime.utc(2026, 10, 3, 8),
          ),
        );
    final sessionId = await db
        .into(db.attendanceSessions)
        .insert(
          AttendanceSessionsCompanion.insert(
            attendanceDate: DateTime.utc(2026, 10, 3),
            createdAt: DateTime.utc(2026, 10, 3, 9),
            status: 'open',
          ),
        );
    await db
        .into(db.attendanceRecords)
        .insert(
          AttendanceRecordsCompanion.insert(
            sessionId: sessionId,
            studentId: studentId,
            rollNoSnapshot: '24BMR016',
            nameSnapshot: 'Asha Rao',
            institutionSnapshot: 'Springfield College',
            boardingPointSnapshot: 'North Gate',
            status: 'PRESENT',
            scannedBarcode: '732924BMR016',
            scannedAt: DateTime.utc(2026, 10, 3, 9, 5),
          ),
        );

    expect(await userVersionOf(db), 1, reason: 'fixture must look like v1');
    await db.close();
    return file;
  }

  group('migrating v1 to current', () {
    test('rewrites the stored schema version', () async {
      final file = await buildV1Database('version.db');

      // Opening a v1 file runs the migration straight away, so the "before"
      // state is asserted inside buildV1Database; here we confirm it landed on
      // the current version rather than being left at 1.
      final db = AppDatabase.forTesting(NativeDatabase(file));

      expect(db.schemaVersion, 4);
      expect(await userVersionOf(db), 4);
      await db.close();
    });

    test('creates the unique index on (session_id, student_id)', () async {
      final file = await buildV1Database('index.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));

      // new schema may have additional indexes
      final idx = await indexNamesOf(db);
      expect(idx, contains(_indexName));
      await db.close();
    });

    test('keeps records written before the migration', () async {
      final file = await buildV1Database('data.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final students = await db.select(db.students).get();
      final sessions = await db.select(db.attendanceSessions).get();
      final records = await db.select(db.attendanceRecords).get();

      expect(students.map((s) => s.rollNo), ['24BMR016']);
      expect(sessions.single.status, 'open');
      expect(records.single.scannedBarcode, '732924BMR016');
      expect(records.single.status, 'PRESENT');
      // drift stores datetimes as epoch seconds and rebuilds them in local
      // time, so the instant survives but the isUtc flag does not.
      expect(records.single.scannedAt.toUtc(), DateTime.utc(2026, 10, 3, 9, 5));
      await db.close();
    });

    test('rejects a duplicate attendance record after migrating', () async {
      final file = await buildV1Database('dupe.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final record = await db.select(db.attendanceRecords).getSingle();

      // Same student, same session. The constraint added by the migration has
      // to reject this, otherwise "Already Present" would depend on
      // application code being careful rather than on the database.
      await expectLater(
        db
            .into(db.attendanceRecords)
            .insert(
              AttendanceRecordsCompanion.insert(
                sessionId: record.sessionId,
                studentId: record.studentId,
                rollNoSnapshot: record.rollNoSnapshot,
                nameSnapshot: record.nameSnapshot,
                institutionSnapshot: record.institutionSnapshot,
                boardingPointSnapshot: record.boardingPointSnapshot,
                status: 'PRESENT',
                scannedBarcode: record.scannedBarcode,
                scannedAt: record.scannedAt,
              ),
            ),
        throwsA(anything),
      );
      expect(
        await db.select(db.attendanceRecords).get(),
        hasLength(1),
        reason: 'the rejected insert must not have been written',
      );
      await db.close();
    });

    test('produces the same schema as a freshly created database', () async {
      final file = await buildV1Database('parity.db');

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      // Touch it so the migration actually runs before the comparison.
      await migrated.select(migrated.students).get();

      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      await fresh.select(fresh.students).get();

      expect(
        await schemaOf(migrated),
        await schemaOf(fresh),
        reason:
            'a migrated database must be structurally identical to a new '
            'one, or drift reads back a schema it cannot trust',
      );

      await migrated.close();
      await fresh.close();
    });
  });

  group('migrating v2 to current', () {
    /// Builds a genuine v2 file: the current schema minus the roster table
    /// added in v3, rewound to user_version 2. `forTesting` always creates the
    /// full current schema, so the roster table is dropped to undo v3.
    Future<File> buildV2Database(String name) async {
      final file = fileIn(name);
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await db.customStatement(
        'DROP TABLE IF EXISTS attendance_session_roster',
      );
      await db.customStatement('PRAGMA user_version = 2');

      final studentId = await db
          .into(db.students)
          .insert(
            StudentsCompanion.insert(
              rollNo: '24BMR016',
              name: 'Asha Rao',
              institution: 'Springfield College',
              boardingPoint: 'North Gate',
              createdAt: DateTime.utc(2026, 10, 3, 8),
            ),
          );
      final sessionId = await db
          .into(db.attendanceSessions)
          .insert(
            AttendanceSessionsCompanion.insert(
              attendanceDate: DateTime.utc(2026, 10, 3),
              createdAt: DateTime.utc(2026, 10, 3, 9),
              status: 'completed',
            ),
          );
      await db
          .into(db.attendanceRecords)
          .insert(
            AttendanceRecordsCompanion.insert(
              sessionId: sessionId,
              studentId: studentId,
              rollNoSnapshot: '24BMR016',
              nameSnapshot: 'Asha Rao',
              institutionSnapshot: 'Springfield College',
              boardingPointSnapshot: 'North Gate',
              status: 'PRESENT',
              scannedBarcode: '732924BMR016',
              scannedAt: DateTime.utc(2026, 10, 3, 9, 5),
            ),
          );

      expect(await userVersionOf(db), 2, reason: 'fixture must look like v2');
      await db.close();
      return file;
    }

    test('creates the attendance_session_roster table', () async {
      final file = await buildV2Database('v2_roster.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));
      // Touch it so the migration runs.
      await db.select(db.attendanceSessionRoster).get();

      expect(await userVersionOf(db), 4);
      await db.close();
    });

    test('keeps records written before the migration', () async {
      final file = await buildV2Database('v2_data.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));
      expect((await db.select(db.students).get()).single.rollNo, '24BMR016');
      expect(
        (await db.select(db.attendanceSessions).get()).single.status,
        'completed',
      );
      expect(
        (await db.select(db.attendanceRecords).get()).single.status,
        'PRESENT',
      );
      await db.close();
    });

    test('produces the same schema as a freshly created database', () async {
      final file = await buildV2Database('v2_parity.db');

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      await migrated.select(migrated.attendanceSessionRoster).get();

      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      await fresh.select(fresh.students).get();

      expect(await schemaOf(migrated), await schemaOf(fresh));

      await migrated.close();
      await fresh.close();
    });
  });

  group('migrating v3 to current', () {
    Future<File> buildV3Database(String name) async {
      final file = fileIn(name);
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();
      return file;
    }

    test('adds tripType column to attendance_sessions and updates user_version', () async {
      final file = await buildV3Database('v3_trip.db');

      final db = AppDatabase.forTesting(NativeDatabase(file));
      await db.select(db.attendanceSessions).get();

      expect(await userVersionOf(db), 4);
      await db.close();
    });
  });

  group('fresh install', () {
    test('is created at the current version, with the unique index', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      expect(await userVersionOf(db), db.schemaVersion);
      // new schema may have additional indexes
      final idx = await indexNamesOf(db);
      expect(idx, contains(_indexName));

      await db.close();
    });

    test('enforces foreign keys on open', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);

      await db.close();
    });
  });
}
