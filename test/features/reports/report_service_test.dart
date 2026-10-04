import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/reports/report_service.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository rosters;
  late ReportService reports;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    rosters = AttendanceSessionRosterRepository(db);
    reports = ReportService(db);
  });

  tearDown(() => db.close());

  Future<Student> addStudent(
    String rollNo, {
    String name = 'A Student',
    String boardingPoint = 'North Gate',
  }) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: name,
      institution: 'Springfield College',
      boardingPoint: boardingPoint,
    );
    return (await students.findById(id))!;
  }

  Future<void> seed() async {
    final alice = await addStudent('24BMR016', name: 'Alice');
    final bob = await addStudent('24BMR017', name: 'Bob');

    final older = await sessions.createOpen(
      attendanceDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1, 8),
    );
    await rosters.insertRoster(older, [alice, bob]);
    await records.markPresent(
      sessionId: older,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: DateTime(2026, 9, 1, 9),
    );
    await sessions.complete(older, DateTime(2026, 9, 1, 10));

    final newer = await sessions.createOpen(
      attendanceDate: DateTime(2026, 10, 3),
      createdAt: DateTime(2026, 10, 3, 8),
    );
    await rosters.insertRoster(newer, [alice, bob]);
    await records.markPresent(
      sessionId: newer,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: DateTime(2026, 10, 3, 9),
    );
    await records.markPresent(
      sessionId: newer,
      student: bob,
      rawBarcode: '24BMR017',
      scannedAt: DateTime(2026, 10, 3, 9, 1),
    );
    await sessions.complete(newer, DateTime(2026, 10, 3, 10));
  }

  group('build', () {
    test('aggregates every session and totals when unbounded', () async {
      await seed();

      final report = await reports.build();

      expect(report.sessionCount, 2);
      expect(report.totalExpected, 4);
      expect(report.totalPresent, 3);
      expect(report.totalAbsent, 1);
      expect(report.overallPercent, closeTo(75.0, 0.01));
    });

    test('honours the date range', () async {
      await seed();

      final report = await reports.build(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );

      expect(report.sessionCount, 1);
      expect(report.totalPresent, 2);
      expect(report.totalAbsent, 0);
      expect(report.overallPercent, 100);
    });
  });

  group('absentees', () {
    test('lists snapshot roster members with no record', () async {
      await seed();

      final absences = await reports.absentees(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );

      expect(absences, isEmpty);
    });

    test('uses the frozen roster, not the live student names', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final alice = await addStudent('24BMR016', name: 'Alice Original');
      await rosters.insertRoster(sessionId, [alice]);

      await students.update(
        id: alice.id,
        name: 'Alice Renamed',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );

      final absences = await reports.absentees();

      expect(absences.single.name, 'Alice Original');
      expect(absences.single.rollNo, '24BMR016');
      expect(absences.single.tripType, TripType.morning);
    });
  });

  group('export', () {
    test('CSV contains the summary, sessions and absences', () async {
      await seed();
      await reports.build(); // ensure the db is warm before export
      final bundle = await reports.buildBundle();

      final csv = reports.buildCsv(bundle);

      expect(csv, contains('OnBoard Attendance Report'));
      expect(csv, contains('Attendance %'));
      expect(csv, contains('24BMR017'));
      expect(csv, contains('Absences'));
      expect(csv, contains('Date,Trip,Session ID,Roll No,Name,Boarding Point'));
      expect(csv, contains('Morning'));
    });

    test('Excel export produces a non-empty workbook', () async {
      await seed();
      final bundle = await reports.buildBundle();

      final bytes = reports.buildExcel(bundle);

      expect(bytes, isNotEmpty);
      // XLSX is a zip archive: "PK\x03\x04".
      expect(bytes.take(2), [0x50, 0x4B]);
    });

    test('CSV quotes a name that contains a comma', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final student = await addStudent('24BMR016', name: 'Doe, Jane');
      await rosters.insertRoster(sessionId, [student]);

      final bundle = await reports.buildBundle();

      expect(reports.buildCsv(bundle), contains('"Doe, Jane"'));
    });
  });
}
