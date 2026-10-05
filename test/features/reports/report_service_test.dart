import 'dart:convert';

import 'package:archive/archive.dart';
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

/// The worksheet XML for every sheet in an encoded workbook.
///
/// Styles have to be checked in the XML rather than through the reader: in
/// excel_community `CellStyle` is write-only, and a fill the writer cannot
/// serialise is dropped without any error, so the decode looks fine either way.
List<String> worksheets(List<int> xlsx) => ZipDecoder()
    .decodeBytes(xlsx)
    .files
    .where((f) => f.name.startsWith('xl/worksheets/sheet'))
    .map((f) => utf8.decode(f.content as List<int>))
    .toList();

String stylesXml(List<int> xlsx) => utf8.decode(
  ZipDecoder()
      .decodeBytes(xlsx)
      .files
      .firstWhere((f) => f.name == 'xl/styles.xml')
      .content as List<int>,
);

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
      // Title, then header, then one row per student.
      expect(roster, hasLength(4));
      expect(
        roster.first.first!.value.toString(),
        'Roster — 2026-10-03 · Morning',
        reason: 'the sheet must record which session it describes',
      );
      expect(roster[1].first!.value.toString(), 'Roll No');
      expect(roster[2][0]!.value.toString(), '24BMR016');
      expect(roster[2][4]!.value.toString(), 'Present');
      expect(roster[3][0]!.value.toString(), '24BMR017');
      expect(
        roster[3][4]!.value.toString(),
        'Absent',
        reason: 'a student with no record row must still be listed',
      );
    });

    test('the Session sheet names its own columns, not the roster ones', () async {
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
      final rows = Excel.decodeBytes(
        await reports.buildSessionExcel(summary),
      ).tables[ReportService.sessionSheet]!.rows;

      expect(
        rows.first.first!.value.toString(),
        startsWith('Attendance Session'),
      );
      expect(
        rows[1].map((cell) => cell?.value.toString()).toList(),
        ['Date', 'Trip', 'Status', 'Present/Total', 'Attendance %'],
        reason: 'the summary row is a session, so it must not borrow roster columns',
      );
      expect(
        rows[2].map((cell) => cell?.value.toString()).toList(),
        ['2026-10-03', 'Morning', 'Open', '1/2', '50.0%'],
      );
    });

    test('the title is merged and the brand fill reaches the file', () async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final alice = await addStudent('24BMR016', name: 'Alice');
      await rosters.insertRoster(sessionId, [alice]);

      final bundle = await reports.buildBundle();
      final summary = bundle.report.sessions.singleWhere(
        (s) => s.sessionId == sessionId,
      );
      final bytes = await reports.buildSessionExcel(summary);
      final styles = stylesXml(bytes);

      // The writer only emits a solid fill for a colour whose alpha byte is FF.
      // A bare RGB hex is dropped silently, which left every header as white text
      // on an unfilled background with nothing to notice it.
      expect(
        styles,
        contains('FF1A73E8'),
        reason: 'the brand fill must survive serialisation',
      );

      // Every fillId has to point at a fill that actually exists, or the count is
      // a lie and readers resolve the style to nothing.
      final fills =
          RegExp(r'<fills[\s\S]*?</fills>').firstMatch(styles)!.group(0)!;
      final present = RegExp(r'<fill[ />]').allMatches(fills).length;
      final xfs =
          RegExp(r'<cellXfs[\s\S]*?</cellXfs>').firstMatch(styles)!.group(0)!;
      final fillIds = RegExp(r'fillId="(\d+)"')
          .allMatches(xfs)
          .map((m) => int.parse(m.group(1)!));
      for (final id in fillIds) {
        expect(id, lessThan(present), reason: 'fillId $id has no fill entry');
      }

      final sheets = worksheets(bytes);
      expect(sheets, hasLength(2));
      for (final xml in sheets) {
        expect(
          xml,
          contains(RegExp(r'<mergeCell ref="A1:[A-Z]+1"')),
          reason: 'the title has to span the sheet, not one column',
        );
      }

      // The title is a heading, not a second banner: the filled header row is the
      // only coloured band. Resolve A1's style index through to its fill.
      final xfList = RegExp(r'<xf\b[^>]*/?>')
          .allMatches(xfs)
          .map((m) => m.group(0)!)
          .toList();
      for (final xml in sheets) {
        final title = RegExp(r'<c r="A1" s="(\d+)"').firstMatch(xml);
        expect(title, isNotNull, reason: 'the title cell needs a style index');
        final fill = RegExp(r'fillId="(\d+)"')
            .firstMatch(xfList[int.parse(title!.group(1)!)])!;
        expect(
          fill.group(1),
          '0',
          reason: 'the title must not carry a fill of its own',
        );
      }
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
    test('CSV contains the sessions and absences, with no summary', () async {
      await seed();
      final bundle = await reports.buildBundle();

      final csv = reports.buildCsv(bundle);

      expect(csv, contains('OnBoard Attendance Report'));
      expect(csv, contains('24BMR017'));
      expect(csv, contains('Absences'));
      expect(csv, contains('Date,Trip,Session ID,Roll No,Name,Boarding Point'));
      expect(csv, contains('Morning'));
      // The derived totals are all derivable from the session rows, so they
      // are not restated where they can only drift from the data.
      expect(csv, isNot(contains('Attendance %')));
      expect(csv, isNot(contains('Expected')));
      expect(csv, isNot(contains('Summary')));
    });

    test('the CSV header states the range and trip it covers', () async {
      await seed();
      final bundle = await reports.buildBundle(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        trip: TripType.evening,
      );

      // Without the summary sheet, the header is the only place the export's
      // scope is recorded.
      final csv = reports.buildCsv(bundle);

      expect(
        csv.split('\r\n').first,
        'OnBoard Attendance Report from 2026-10-01 to 2026-10-31 (Evening)',
      );
    });

    test('the range workbook has sessions and absences, and no summary', () async {
      await seed();
      final bundle = await reports.buildBundle();

      final bytes = reports.buildExcel(bundle);

      expect(bytes, isNotEmpty);
      // XLSX is a zip archive: "PK\x03\x04".
      expect(bytes.take(2), [0x50, 0x4B]);

      final workbook = Excel.decodeBytes(bytes);
      expect(workbook.tables.keys, [
        ReportService.sessionsSheet,
        ReportService.absencesSheet,
      ]);
      expect(
        workbook.sheets[ReportService.sessionsSheet],
        isNotNull,
        reason: 'the sessions sheet is what should open by default',
      );
      expect(
        workbook.tables.keys,
        isNot(contains('Summary')),
        reason: 'totals are derivable from the session rows',
      );
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
