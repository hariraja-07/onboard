import 'package:drift/native.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/core/export/data_export_service.dart';

void main() {
  late AppDatabase db;
  late DataExportService export;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    export = DataExportService(db);
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
  });

  tearDown(() => db.close());

  test(
    'writes a sheet per table with a header and one row per record',
    () async {
      final studentId = await students.insert(
        rollNo: '24BMR016',
        name: 'Asha Rao',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );
      final student = (await students.findById(studentId))!;
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime.utc(2026, 10, 3),
        createdAt: DateTime.utc(2026, 10, 3, 9),
      );
      await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: DateTime.utc(2026, 10, 3, 9, 5),
      );

      final bytes = await export.build();
      expect(bytes, isNotNull);

      final workbook = Excel.decodeBytes(bytes!);
      expect(
        workbook.tables.keys,
        containsAll([
          DataExportService.studentsSheet,
          DataExportService.sessionsSheet,
          DataExportService.recordsSheet,
        ]),
      );

      final studentRows =
          workbook.tables[DataExportService.studentsSheet]!.rows;
      expect(studentRows.first.first!.value.toString(), 'ID');
      expect(studentRows, hasLength(2));

      final recordRows = workbook.tables[DataExportService.recordsSheet]!.rows;
      expect(recordRows, hasLength(2));
      expect(recordRows[1][3]!.value.toString(), '24BMR016');
      expect(recordRows[1][7]!.value.toString(), 'PRESENT');

      final sessionRows =
          workbook.tables[DataExportService.sessionsSheet]!.rows;
      expect(sessionRows.first[2]!.value.toString(), 'Trip');
      expect(sessionRows[1][2]!.value.toString(), 'Morning');
    },
  );

  test(
    'an empty database still encodes the three sheets with headers',
    () async {
      final bytes = await export.build();
      expect(bytes, isNotNull);

      final workbook = Excel.decodeBytes(bytes!);
      for (final name in [
        DataExportService.studentsSheet,
        DataExportService.sessionsSheet,
        DataExportService.recordsSheet,
      ]) {
        expect(workbook.tables[name]!.rows, hasLength(1));
      }
    },
  );

  test('filenames are timestamped and distinct', () {
    final a = DataExportService.fileNameFor(DateTime(2026, 10, 3, 9, 5, 1));
    final b = DataExportService.fileNameFor(DateTime(2026, 10, 3, 9, 5, 2));
    expect(a, endsWith('.xlsx'));
    expect(a, isNot(b));
  });
}
