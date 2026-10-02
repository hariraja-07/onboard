import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;

  final scannedAt = DateTime.utc(2026, 10, 3, 9, 5);
  var today = DateTime.utc(2026, 10, 3);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
  });

  tearDown(() => db.close());

  Future<Student> addStudent(String rollNo) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: 'Student $rollNo',
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    return (await students.findById(id))!;
  }

  Future<int> openSession({DateTime? forDate}) async {
    return sessions.createOpen(
      attendanceDate: forDate ?? today,
      createdAt: DateTime.utc(2026, 10, 3, 9),
    );
  }

  group('markPresent', () {
    test('inserts a row and reports it as new', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      final result = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt,
      );

      expect(result.isNew, isTrue);
      expect(result.record.sessionId, sessionId);
      expect(result.record.studentId, student.id);
      expect(await records.forSession(sessionId), hasLength(1));
    });

    test('copies the student details onto the record', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      final result = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt,
      );

      final record = result.record;
      expect(record.rollNoSnapshot, student.rollNo);
      expect(record.nameSnapshot, student.name);
      expect(record.institutionSnapshot, student.institution);
      expect(record.boardingPointSnapshot, student.boardingPoint);
      expect(record.status, AttendanceStatus.present.wireValue);
    });

    test('stores the barcode exactly as scanned', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      final result = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '  732924bmr016  ',
        scannedAt: scannedAt,
      );

      expect(result.record.scannedBarcode, '  732924bmr016  ');
    });

    test('a second scan is reported as already present', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      final first = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt,
      );
      final second = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt.add(const Duration(minutes: 5)),
      );

      expect(first.isNew, isTrue);
      expect(second.isNew, isFalse);
      expect(
        await records.forSession(sessionId),
        hasLength(1),
        reason: 'a repeat scan must not create a second record',
      );
      expect(second.record.id, first.record.id);
    });

    test('a repeat scan keeps the original arrival time', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt,
      );
      final repeat = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: '732924BMR016',
        scannedAt: scannedAt.add(const Duration(hours: 1)),
      );

      expect(
        repeat.record.scannedAt.toUtc(),
        scannedAt,
        reason: 'the record must show when the student arrived, not when the '
            'card happened to be read again',
      );
    });

    test('the same student can be marked in a different session', () async {
      final first = await openSession();
      final second = await openSession(forDate: DateTime.utc(2026, 10, 4));
      final student = await addStudent('24BMR016');

      final a = await records.markPresent(
        sessionId: first,
        student: student,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );
      final b = await records.markPresent(
        sessionId: second,
        student: student,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );

      expect(a.isNew, isTrue);
      expect(b.isNew, isTrue);
    });

    test('the database itself refuses a duplicate, not just this method',
        () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');
      await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );

      // Deliberately bypassing markPresent. If this succeeds, then "Already
      // Present" is only being enforced by application code, and any other
      // writer could produce duplicates.
      await expectLater(
        db.into(db.attendanceRecords).insert(
              AttendanceRecordsCompanion.insert(
                sessionId: sessionId,
                studentId: student.id,
                rollNoSnapshot: student.rollNo,
                nameSnapshot: student.name,
                institutionSnapshot: student.institution,
                boardingPointSnapshot: student.boardingPoint,
                status: 'PRESENT',
                scannedBarcode: 'x',
                scannedAt: scannedAt,
              ),
            ),
        throwsA(anything),
      );
      expect(await records.forSession(sessionId), hasLength(1));
    });
  });

  group('lookups', () {
    test('presentStudentIds returns only marked students', () async {
      final sessionId = await openSession();
      final asha = await addStudent('24BMR016');
      await addStudent('25BMR017');

      await records.markPresent(
        sessionId: sessionId,
        student: asha,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );

      expect(await records.presentStudentIds(sessionId), {asha.id});
    });

    test('presentStudentIds is scoped to one session', () async {
      final first = await openSession();
      final second = await openSession(forDate: DateTime.utc(2026, 10, 4));
      final student = await addStudent('24BMR016');

      await records.markPresent(
        sessionId: second,
        student: student,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );

      expect(await records.presentStudentIds(first), isEmpty);
      expect(await records.presentStudentIds(second), {student.id});
    });

    test('findForStudent returns null before marking and the row after', () async {
      final sessionId = await openSession();
      final student = await addStudent('24BMR016');

      expect(await records.findForStudent(sessionId, student.id), isNull);

      final marked = await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: 'x',
        scannedAt: scannedAt,
      );

      expect((await records.findForStudent(sessionId, student.id))!.id,
          marked.record.id);
    });
  });

  group('sessions', () {
    test('createOpen writes the open status', () async {
      final id = await openSession();

      final session = await sessions.findById(id);
      expect(session!.status, AttendanceSessionStatus.open.wireValue);
      expect(session.completedAt, isNull);
    });

    test('findOpenForDate finds the open session for that day', () async {
      final id = await openSession();

      final found = await sessions.findOpenForDate(DateTime.utc(2026, 10, 3));

      expect(found!.id, id);
    });

    test('findOpenForDate ignores a completed session', () async {
      final id = await openSession();
      await sessions.complete(id, DateTime.utc(2026, 10, 3, 17));

      expect(await sessions.findOpenForDate(DateTime.utc(2026, 10, 3)), isNull);
    });

    test('findOpenForDate ignores other days', () async {
      await openSession(forDate: DateTime.utc(2026, 10, 3));

      expect(await sessions.findOpenForDate(DateTime.utc(2026, 10, 4)), isNull);
    });

    test('findOpenForDate matches a session stored on a different time of day',
        () async {
      // Sessions are stored as a datetime but represent a whole day, so a
      // session written at 18:00 must still be found by a 09:00 lookup.
      await sessions.insert(
        attendanceDate: DateTime.utc(2026, 10, 3, 18),
        createdAt: DateTime.utc(2026, 10, 3, 18),
        status: AttendanceSessionStatus.open.wireValue,
      );

      expect(await sessions.findOpenForDate(DateTime.utc(2026, 10, 3, 9)),
          isNotNull);
    });

    test('complete records the finish time and closed status', () async {
      final id = await openSession();
      final finishedAt = DateTime.utc(2026, 10, 3, 17, 30);

      await sessions.complete(id, finishedAt);

      final session = await sessions.findById(id);
      expect(session!.status, AttendanceSessionStatus.completed.wireValue);
      expect(session.completedAt!.toUtc(), finishedAt);
    });
  });

  group('AttendanceStatus', () {
    test('round-trips through its stored value', () {
      for (final status in AttendanceStatus.values) {
        expect(AttendanceStatus.fromWireValue(status.wireValue), status);
      }
    });

    test('reads PRESENT but does not recognise anything else as present', () {
      expect(AttendanceStatus.fromWireValue('PRESENT'),
          AttendanceStatus.present);
      expect(AttendanceStatus.fromWireValue('ABSENT'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromWireValue('present'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromWireValue('nonsense'),
          AttendanceStatus.absent);
    });
  });

  group('AttendanceScanOutcome', () {
    test('uses the agreed operator-facing wording', () {
      expect(AttendanceScanOutcome.marked.label, 'Attendance Marked');
      expect(AttendanceScanOutcome.alreadyPresent.label, 'Already Present');
      expect(AttendanceScanOutcome.notFound.label, 'Student Not Found');
    });

    test('an ambiguous barcode reports the same as an unknown one', () {
      expect(AttendanceScanOutcome.ambiguous.label,
          AttendanceScanOutcome.notFound.label);
      expect(AttendanceScanOutcome.ambiguous.didMark, isFalse);
      expect(AttendanceScanOutcome.notFound.didMark, isFalse);
      expect(AttendanceScanOutcome.alreadyPresent.didMark, isFalse);
      expect(AttendanceScanOutcome.marked.didMark, isTrue);
    });
  });
}