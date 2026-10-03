import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/backup/backup_models.dart';
import 'package:onboard/core/backup/backup_service.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';

void main() {
  late AppDatabase db;
  late BackupService service;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository roster;

  final base = DateTime.utc(2026, 10, 3, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(db);
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    roster = AttendanceSessionRosterRepository(db);
  });

  tearDown(() => db.close());

  Future<Student> seedStudent(String rollNo) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: 'Student $rollNo',
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    return (await students.findById(id))!;
  }

  Future<void> seedFullDataset() async {
    final asha = await seedStudent('24BMR016');
    await seedStudent('24BMR017');
    final sessionId = await sessions.createOpen(
      attendanceDate: DateTime.utc(2026, 10, 3),
      createdAt: base,
    );
    await records.markPresent(
      sessionId: sessionId,
      student: asha,
      rawBarcode: '732924BMR016',
      scannedAt: base.add(const Duration(minutes: 5)),
    );
    await roster.insertRoster(sessionId, [asha], createdAt: base);
  }

  Uint8List bytesOf(Map<String, Object?> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  Map<String, Object?> validEnvelope() => {
    'format': BackupService.format,
    'formatVersion': BackupService.formatVersion,
    'appVersion': '1.0.0',
    'schemaVersion': db.schemaVersion,
    'exportedAt': base.millisecondsSinceEpoch,
    'settings': <String, Object?>{},
    'data': {
      'students': <Object?>[],
      'attendanceSessions': <Object?>[],
      'attendanceRecords': <Object?>[],
      'attendanceSessionRoster': <Object?>[],
    },
  };

  Map<String, Object?> studentJson(int id, String rollNo) => {
    'id': id,
    'rollNo': rollNo,
    'name': 'Student $rollNo',
    'institution': 'Springfield College',
    'boardingPoint': 'North Gate',
    'createdAt': base.millisecondsSinceEpoch,
    'updatedAt': null,
  };

  Map<String, Object?> recordJson(int id, int sessionId, int studentId) => {
    'id': id,
    'sessionId': sessionId,
    'studentId': studentId,
    'rollNoSnapshot': '24BMR016',
    'nameSnapshot': 'Student',
    'institutionSnapshot': 'Springfield College',
    'boardingPointSnapshot': 'North Gate',
    'status': 'PRESENT',
    'scannedBarcode': '732924BMR016',
    'scannedAt': base.millisecondsSinceEpoch,
  };

  group('round trip', () {
    test('snapshot -> encode -> decode preserves every row', () async {
      await seedFullDataset();

      final decoded = service.decodeAndValidate(
        service.encode(await service.snapshot()),
      );

      expect(decoded.studentCount, 2);
      expect(decoded.sessionCount, 1);
      expect(decoded.recordCount, 1);
      expect(decoded.rosterCount, 1);
      expect(decoded.formatVersion, BackupService.formatVersion);
      expect(decoded.schemaVersion, db.schemaVersion);
      expect(decoded.students.map((s) => s.rollNo).toSet(), {
        '24BMR016',
        '24BMR017',
      });
      expect(decoded.records.single.nameSnapshot, 'Student 24BMR016');
      expect(
        decoded.records.single.scannedAt.isAtSameMomentAs(
          base.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(decoded.info.earliestSession, isNotNull);
    });

    test('restore replaces current data with the backup', () async {
      await seedFullDataset();
      final backup = service.decodeAndValidate(
        service.encode(await service.snapshot()),
      );

      await seedStudent('24BMR999');
      expect(await students.getAll(), hasLength(3));

      await service.restore(backup);

      final restored = await students.getAll();
      expect(restored.map((s) => s.rollNo).toSet(), {'24BMR016', '24BMR017'});
      expect(await db.select(db.attendanceSessions).get(), hasLength(1));
      expect(await db.select(db.attendanceRecords).get(), hasLength(1));
      expect(await db.select(db.attendanceSessionRoster).get(), hasLength(1));
    });

    test('restore keeps ids so references still resolve', () async {
      await seedFullDataset();
      final backup = service.decodeAndValidate(
        service.encode(await service.snapshot()),
      );

      await service.restore(backup);

      final record = (await db.select(db.attendanceRecords).get()).single;
      final student = await students.findById(record.studentId);
      expect(student, isNotNull);
      expect(
        record.sessionId,
        (await db.select(db.attendanceSessions).get()).single.id,
      );
    });
  });

  group('clearAll', () {
    test('removes all data and resets auto-increment ids', () async {
      await seedFullDataset();

      await service.clearAll();

      expect(await db.select(db.students).get(), isEmpty);
      expect(await db.select(db.attendanceSessions).get(), isEmpty);
      expect(await db.select(db.attendanceRecords).get(), isEmpty);
      expect(await db.select(db.attendanceSessionRoster).get(), isEmpty);

      final newId = await students.insert(
        rollNo: '24BMR001',
        name: 'Fresh Start',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );
      expect(newId, 1);
    });
  });

  group('decodeAndValidate rejects', () {
    test('an empty file', () {
      expect(
        () => service.decodeAndValidate(Uint8List(0)),
        throwsA(isA<BackupException>()),
      );
    });

    test('a file that is not text', () {
      expect(
        () => service.decodeAndValidate(Uint8List.fromList([0xff, 0xfe, 0x00])),
        throwsA(isA<BackupException>()),
      );
    });

    test('JSON that is not an OnBoard backup', () {
      expect(
        () => service.decodeAndValidate(
          Uint8List.fromList(utf8.encode('this is not json at all')),
        ),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => service.decodeAndValidate(bytesOf({'hello': 'world'})),
        throwsA(isA<BackupException>()),
      );
    });

    test('a backup from a newer format version', () async {
      final envelope = validEnvelope()
        ..['formatVersion'] = BackupService.formatVersion + 1;

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a backup from a newer schema version', () async {
      final envelope = validEnvelope()
        ..['schemaVersion'] = db.schemaVersion + 1;

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a missing data section', () async {
      final envelope = validEnvelope()..remove('data');

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(isA<BackupException>()),
      );
    });

    test('a malformed row', () async {
      final envelope = validEnvelope();
      (envelope['data']! as Map<String, Object?>)['students'] = [
        {'id': 'not a number'},
      ];

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(isA<BackupException>()),
      );
    });

    test('duplicate ids', () async {
      final envelope = validEnvelope();
      (envelope['data']! as Map<String, Object?>)['students'] = [
        studentJson(1, 'A'),
        studentJson(1, 'B'),
      ];

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('same id'),
          ),
        ),
      );
    });

    test('duplicate session/student pairs', () async {
      final envelope = validEnvelope();
      (envelope['data']! as Map<String, Object?>)['attendanceRecords'] = [
        recordJson(1, 1, 1),
        recordJson(2, 1, 1),
      ];

      expect(
        () => service.decodeAndValidate(bytesOf(envelope)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
    });
  });
}
