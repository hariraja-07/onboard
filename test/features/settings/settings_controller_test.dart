import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/backup/backup_service.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/core/export/data_export_service.dart';
import 'package:onboard/features/settings/backup_file_gateway.dart';
import 'package:onboard/features/settings/settings_controller.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository roster;
  late FakeBackupFileGateway gateway;
  var reloadCount = 0;

  final base = DateTime.utc(2026, 10, 3, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    roster = AttendanceSessionRosterRepository(db);
    gateway = FakeBackupFileGateway();
    reloadCount = 0;
  });

  tearDown(() => db.close());

  DataManagementController build() => DataManagementController(
    backupService: BackupService(db),
    exportService: DataExportService(db),
    gateway: gateway,
    reloadData: () async => reloadCount++,
  );

  Future<void> seed(String rollNo) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: 'Student $rollNo',
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    final student = (await students.findById(id))!;
    final sessionId = await sessions.createOpen(
      attendanceDate: DateTime.utc(2026, 10, 3),
      createdAt: base,
    );
    await records.markPresent(
      sessionId: sessionId,
      student: student,
      rawBarcode: '7329$rollNo',
      scannedAt: base,
    );
    await roster.insertRoster(sessionId, [student], createdAt: base);
  }

  group('backup', () {
    test('encodes the database and reports where it was saved', () async {
      await seed('24BMR016');
      final controller = build();

      await controller.backUp();

      expect(gateway.savedBackupBytes, isNotNull);
      expect(controller.state.status, DataManagementStatus.done);
      expect(controller.state.message, contains('/saved/backup.onboard'));

      final decoded = BackupService(
        db,
      ).decodeAndValidate(gateway.savedBackupBytes!);
      expect(decoded.studentCount, 1);
      expect(decoded.sessionCount, 1);
    });

    test('cancelling the save dialog leaves a clean idle state', () async {
      gateway.saveBackupResult = null;
      final controller = build();

      await controller.backUp();

      expect(controller.state.status, DataManagementStatus.idle);
      expect(controller.state.message, isNull);
      expect(controller.state.error, isNull);
    });
  });

  group('export', () {
    test('builds a workbook and hands it to the save dialog', () async {
      await seed('24BMR016');
      final controller = build();

      await controller.exportData();

      expect(gateway.savedExportBytes, isNotNull);
      expect(controller.state.message, contains('/saved/export.xlsx'));
    });
  });

  group('restore', () {
    test('a valid file moves to review with its info', () async {
      await seed('24BMR016');
      final bytes = BackupService(
        db,
      ).encode(await BackupService(db).snapshot());
      gateway.pickResult = PickedBackup(name: 'b.onboard', bytes: bytes);

      final controller = build();
      final ready = await controller.chooseBackupToRestore();

      expect(ready, isTrue);
      expect(controller.state.status, DataManagementStatus.review);
      expect(controller.state.pendingInfo!.studentCount, 1);
    });

    test('an invalid file fails with a readable message', () async {
      gateway.pickResult = PickedBackup(
        name: 'notes.txt',
        bytes: Uint8List.fromList('hello'.codeUnits),
      );

      final controller = build();
      final ready = await controller.chooseBackupToRestore();

      expect(ready, isFalse);
      expect(controller.state.status, DataManagementStatus.failed);
      expect(controller.state.error, contains('not an OnBoard backup'));
    });

    test('confirming writes a safety copy, restores and reloads', () async {
      await seed('24BMR016');
      final bytes = BackupService(
        db,
      ).encode(await BackupService(db).snapshot());

      // Change the database to something else, then restore the old snapshot.
      await db.delete(db.attendanceRecords).go();
      await db.delete(db.attendanceSessionRoster).go();
      await db.delete(db.attendanceSessions).go();
      await db.delete(db.students).go();
      await seed('24BMR777');

      gateway.pickResult = PickedBackup(name: 'b.onboard', bytes: bytes);
      final controller = build();
      await controller.chooseBackupToRestore();
      await controller.confirmRestore();

      expect(controller.state.status, DataManagementStatus.done);
      expect(gateway.safetyBackupBytes, isNotNull);
      expect(reloadCount, 1);
      expect((await students.getAll()).map((s) => s.rollNo).toSet(), {
        '24BMR016',
      });
    });

    test('a failed safety copy aborts the restore', () async {
      await seed('24BMR016');
      final bytes = BackupService(
        db,
      ).encode(await BackupService(db).snapshot());
      gateway.pickResult = PickedBackup(name: 'b.onboard', bytes: bytes);
      gateway.safetyBackupThrows = true;

      final controller = build();
      await controller.chooseBackupToRestore();
      await controller.confirmRestore();

      expect(controller.state.status, DataManagementStatus.failed);
      expect(reloadCount, 0);
      expect(await students.getAll(), hasLength(1));
    });
  });

  group('clear', () {
    test('writes a safety copy first, then deletes everything', () async {
      await seed('24BMR016');
      final controller = build();

      await controller.clearAllData();

      expect(controller.state.status, DataManagementStatus.done);
      expect(gateway.safetyBackupBytes, isNotNull);
      expect(reloadCount, 1);
      expect(await students.getAll(), isEmpty);
      expect(await db.select(db.attendanceRecords).get(), isEmpty);
    });
  });
}

/// In-memory stand-in for the picker and disk.
class FakeBackupFileGateway implements BackupFileGateway {
  PickedBackup? pickResult;
  String? saveBackupResult = '/saved/backup.onboard';
  String? saveExportResult = '/saved/export.xlsx';
  String safetyPath = '/saved/safety.onboard';
  bool safetyBackupThrows = false;

  Uint8List? savedBackupBytes;
  Uint8List? savedExportBytes;
  Uint8List? safetyBackupBytes;

  @override
  Future<PickedBackup?> pickBackup() async => pickResult;

  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async {
    savedBackupBytes = bytes;
    return saveBackupResult;
  }

  @override
  Future<String?> saveExport(Uint8List bytes, String fileName) async {
    savedExportBytes = bytes;
    return saveExportResult;
  }

  @override
  Future<String> writeSafetyBackup(Uint8List bytes, String fileName) async {
    if (safetyBackupThrows) {
      throw StateError('disk full');
    }
    safetyBackupBytes = bytes;
    return safetyPath;
  }
}
