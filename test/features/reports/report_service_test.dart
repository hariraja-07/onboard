import 'package:drift/native.dart';
import 'package:excel_community/excel_community.dart';
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

    final evening = await sessions.createOpen(
      attendanceDate: DateTime(2026, 10, 3),
      tripType: TripType.evening.wireValue,
      createdAt: DateTime(2026, 10, 3, 17),
    );
    await rosters.insertRoster(evening, [alice]);
    await records.markPresent(
      sessionId: evening,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: DateTime(2026, 10, 3, 17, 30),
    );
    await sessions.complete(evening, DateTime(2026, 10, 3, 18));

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

      expect(report.sessionCount, 3);
      expect(report.totalExpected, 5);
      expect(report.totalPresent, 4);
      expect(report.totalAbsent, 1);
      expect(report.overallPercent, closeTo(80.0, 0.01));
    });

    test('honours the date range', () async {
      await seed();

      final report = await reports.build(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );

      expect(report.sessionCount, 2);
      expect(report.totalPresent, 3);
      expect(report.totalAbsent, 0);
      expect(report.overallPercent, 100);
    });

    test('a trip filter narrows to one trip of the day', () async {
      await seed();

      final evening = await reports.build(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        trip: TripType.evening,
      );
      final morning = await reports.build(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        trip: TripType.morning,
      );

      // The seeded day has a morning and an evening session, so this only
      // holds if the trip reaches the query rather than being ignored.
      expect(evening.sessionCount, 1);
      expect(evening.sessions.single.tripType, TripType.evening);
      expect(morning.sessionCount, 1);
      expect(morning.sessions.single.tripType, TripType.morning);
    });

    test('the trip filter combines with a date range', () async {
      await seed();

      final report = await reports.build(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        trip: TripType.evening,
      );

      expect(report.sessionCount, 0, reason: 'September had no evening trip');
      expect(report.isEmpty, isTrue);
    });
  });

  group('ReportRange', () {
    test('the trip is part of equality and hashing', () {
      // ReportRange keys an autoDispose family provider, so a trip left out of
      // these would serve a cached bundle for the other trip.
      const morning = ReportRange(
        from: null,
        to: null,
        trip: TripType.morning,
      );
      const evening = ReportRange(trip: TripType.evening);

      expect(morning, isNot(evening));
      expect(morning.hashCode, isNot(evening.hashCode));
      expect(morning, equals(const ReportRange(trip: TripType.morning)));
      expect(morning, isNot(equals(const ReportRange())));
    });

    test('withTrip keeps the dates and withDates keeps the trip', () {
      final range = ReportRange(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 3),
        trip: TripType.evening,
      );

      expect(
        range.withTrip(TripType.morning).trip,
        TripType.morning,
      );
      expect(range.withTrip(TripType.morning).from, DateTime(2026, 10, 1));
      expect(
        range.withDates(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 2)).trip,
        TripType.evening,
      );
    });

    test('the label names the trip as well as the dates', () {
      expect(const ReportRange().label, 'All time');
      expect(
        ReportRange(
          from: DateTime(2026, 9, 29),
          to: DateTime(2026, 10, 4),
          trip: TripType.evening,
        ).label,
        '2026-09-29 – 2026-10-04 · Evening',
      );
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

  group('per-session export', () {
    test('the file is named after the session, not the moment of export', () {
      final name = ReportService.sessionFileName(
        AttendanceSessionSummary(
          sessionId: 7,
          attendanceDate: DateTime(2026, 10, 5),
          tripType: TripType.evening,
          status: AttendanceSessionStatus.completed,
          total: 2,
          present: 1,
          absent: 1,
          percent: 50,
        ),
      );

      expect(name, 'onboard_attendance_2026-10-05_evening.xlsx');
    });

    test('lists the whole roster and marks who was absent', () async {
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
        scannedAt: DateTime(2026, 10, 3, 9, 5),
      );

      final bundle = await reports.buildBundle();
      final summary = bundle.report.sessions.singleWhere(
        (s) => s.sessionId == sessionId,
      );
      final bytes = await reports.buildSessionExcel(summary);

      expect(bytes, isNotEmpty);
      expect(bytes.take(2), [0x50, 0x4B]);

      // XLSX is zipped, so the rows have to be read back through the reader
      // rather than searched for as text in the archive.
      final workbook = Excel.decodeBytes(bytes);
      final roster = workbook.tables[ReportService.rosterSheet]!.rows;

      expect(
        workbook.tables.keys,
        containsAll([
          ReportService.sessionSheet,
          ReportService.rosterSheet,
        ]),
      );
      // Header, then one row per student.
      expect(roster, hasLength(3));
      expect(roster.first.first!.value.toString(), 'Roll No');
      expect(roster[1][0]!.value.toString(), '24BMR016');
      expect(roster[1][4]!.value.toString(), 'Present');
      expect(roster[2][0]!.value.toString(), '24BMR017');
      expect(
        roster[2][4]!.value.toString(),
        'Absent',
        reason: 'a student with no record row must still be listed',
      );
    });

    test('reads the frozen roster rather than the live student name', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final alice = await addStudent('24BMR016', name: 'Alice');
      await rosters.insertRoster(sessionId, [alice]);
      await students.update(
        id: alice.id,
        rollNo: alice.rollNo,
        name: 'Renamed Later',
        institution: alice.institution,
        boardingPoint: alice.boardingPoint,
      );

      final bundle = await reports.buildBundle();
      final summary = bundle.report.sessions.singleWhere(
        (s) => s.sessionId == sessionId,
      );
      final roster = Excel.decodeBytes(
        await reports.buildSessionExcel(summary),
      ).tables[ReportService.rosterSheet]!.rows;
      final text = [
        for (final row in roster) row.map((cell) => cell?.value).join(' '),
      ].join('\n');

      expect(text, contains('Alice'));
      expect(text, isNot(contains('Renamed Later')));
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
