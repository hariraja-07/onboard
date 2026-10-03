import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/history/history_controller.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository rosters;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    rosters = AttendanceSessionRosterRepository(db);
  });

  tearDown(() => db.close());

  Future<Student> addStudent(
    String rollNo, {
    String name = 'A Student',
    String institution = 'Springfield College',
    String boardingPoint = 'North Gate',
  }) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: name,
      institution: institution,
      boardingPoint: boardingPoint,
    );
    return (await students.findById(id))!;
  }

  ProviderContainer container() {
    final value = ProviderContainer(
      overrides: [
        attendanceSessionRepositoryProvider.overrideWithValue(sessions),
        attendanceRecordRepositoryProvider.overrideWithValue(records),
        attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  group('listSessions', () {
    test('aggregates present and absent against the frozen roster', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final alice = await addStudent('24BMR016', name: 'Alice');
      final bob = await addStudent('24BMR017', name: 'Bob');
      final carol = await addStudent('24BMR018', name: 'Carol');
      await rosters.insertRoster(sessionId, [alice, bob, carol]);
      await records.markPresent(
        sessionId: sessionId,
        student: alice,
        rawBarcode: '24BMR016',
        scannedAt: DateTime(2026, 10, 3, 9),
      );
      await records.markPresent(
        sessionId: sessionId,
        student: bob,
        rawBarcode: '24BMR017',
        scannedAt: DateTime(2026, 10, 3, 9, 5),
      );

      final summaries = await sessions.listSessions();

      expect(summaries, hasLength(1));
      final summary = summaries.single;
      expect(summary.total, 3);
      expect(summary.present, 2);
      expect(summary.absent, 1);
      expect(summary.percent, closeTo(66.67, 0.1));
    });

    test('an empty session reports 0% rather than NaN', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      expect(sessionId, greaterThan(0));

      final summary = (await sessions.listSessions()).single;

      expect(summary.total, 0);
      expect(summary.percent, 0);
    });
  });

  group('sessionDetailsProvider', () {
    test(
      'reads names and institutions from the snapshot, not the student',
      () async {
        final sessionId = await sessions.createOpen(
          attendanceDate: DateTime(2026, 10, 3),
          createdAt: DateTime(2026, 10, 3, 8),
        );
        final alice = await addStudent(
          '24BMR016',
          name: 'Alice Original',
          institution: 'Old College',
          boardingPoint: 'North Gate',
        );
        await rosters.insertRoster(sessionId, [alice]);
        await records.markPresent(
          sessionId: sessionId,
          student: alice,
          rawBarcode: '24BMR016',
          scannedAt: DateTime(2026, 10, 3, 9),
        );

        // The student is renamed and moved after the session was taken.
        await students.update(
          id: alice.id,
          name: 'Alice Renamed',
          institution: 'New College',
          boardingPoint: 'South Gate',
        );

        final details = await container().read(
          sessionDetailsProvider(sessionId).future,
        );

        final entry = details.entries.single;
        expect(entry.name, 'Alice Original');
        expect(entry.institution, 'Old College');
        expect(entry.boardingPoint, 'North Gate');
        expect(entry.status, AttendanceStatus.present);
        expect(entry.scannedAt, DateTime(2026, 10, 3, 9));
      },
    );

    test(
      'marks students with no record as absent and keeps the scan time off',
      () async {
        final sessionId = await sessions.createOpen(
          attendanceDate: DateTime(2026, 10, 3),
          createdAt: DateTime(2026, 10, 3, 8),
        );
        final alice = await addStudent('24BMR016', name: 'Alice');
        final bob = await addStudent('24BMR017', name: 'Bob');
        await rosters.insertRoster(sessionId, [alice, bob]);
        await records.markPresent(
          sessionId: sessionId,
          student: alice,
          rawBarcode: '24BMR016',
          scannedAt: DateTime(2026, 10, 3, 9),
        );

        final details = await container().read(
          sessionDetailsProvider(sessionId).future,
        );

        final bobEntry = details.entries.firstWhere(
          (entry) => entry.rollNo == '24BMR017',
        );
        expect(bobEntry.status, AttendanceStatus.absent);
        expect(bobEntry.scannedAt, isNull);
        expect(details.summary.present, 1);
        expect(details.summary.absent, 1);
      },
    );
  });

  group('branching', () {
    AttendanceHistoryEntry entry({
      required String rollNo,
      required String name,
      String institution = 'Springfield College',
      String boardingPoint = 'North Gate',
      AttendanceStatus status = AttendanceStatus.absent,
    }) {
      return AttendanceHistoryEntry(
        sessionId: 1,
        studentId: rollNo.hashCode,
        rollNo: rollNo,
        name: name,
        institution: institution,
        boardingPoint: boardingPoint,
        status: status,
      );
    }

    final details = AttendanceSessionDetails(
      summary: AttendanceSessionSummary(
        sessionId: 1,
        attendanceDate: DateTime(2026, 10, 3),
        status: AttendanceSessionStatus.completed,
        total: 0,
        present: 0,
        absent: 0,
        percent: 0,
      ),
      entries: [
        entry(rollNo: '24BMR016', name: 'Alice'),
        entry(
          rollNo: '24BMR017',
          name: 'Bob',
          institution: 'Shelbyville College',
          boardingPoint: 'South Gate',
          status: AttendanceStatus.present,
        ),
      ],
    );

    test('filters by status', () {
      final present = details.filtered(
        const AttendanceHistoryFilters(status: AttendanceFilter.present),
      );
      expect(present.map((e) => e.rollNo), ['24BMR017']);
    });

    test('filters by institution and boarding point', () {
      final filtered = details.filtered(
        const AttendanceHistoryFilters(
          institution: 'Shelbyville College',
          boardingPoint: 'South Gate',
        ),
      );
      expect(filtered.map((e) => e.rollNo), ['24BMR017']);
    });

    test('searches roll number and name only', () {
      expect(
        details
            .filtered(const AttendanceHistoryFilters(query: 'alice'))
            .map((e) => e.rollNo),
        ['24BMR016'],
      );
      expect(
        details
            .filtered(const AttendanceHistoryFilters(query: 'gate'))
            .map((e) => e.rollNo),
        isEmpty,
      );
    });

    test('lists the distinct dropdown options in sorted order', () {
      expect(details.institutions, [
        'Shelbyville College',
        'Springfield College',
      ]);
      expect(details.boardingPoints, ['North Gate', 'South Gate']);
    });
  });
}
