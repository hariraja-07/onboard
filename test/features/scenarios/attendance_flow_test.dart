import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/attendance_controller.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/reports/report_service.dart';

/// A full day, end to end: register students, run a session, finish it, read
/// the report, then delete a student and confirm the cascade.
void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository rosters;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    rosters = AttendanceSessionRosterRepository(db);
    container = ProviderContainer(
      overrides: [
        studentRepositoryProvider.overrideWithValue(students),
        attendanceSessionRepositoryProvider.overrideWithValue(sessions),
        attendanceRecordRepositoryProvider.overrideWithValue(records),
        attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => db.close());

  Future<void> addStudent(String rollNo, String name) async {
    await students.insert(
      rollNo: rollNo,
      name: name,
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
  }

  test('a session through to a report and a cascade delete', () async {
    await addStudent('24BMR016', 'Alice');
    await addStudent('24BMR017', 'Bob');
    await addStudent('24BMR018', 'Carol');

    final controller = container.read(attendanceControllerProvider.notifier);
    // Keep the autoDispose controller alive across the awaited steps.
    container.listen(attendanceControllerProvider, (_, _) {});

    await controller.load();
    expect(
      container.read(attendanceControllerProvider).phase,
      AttendancePhase.awaitingStart,
    );

    await controller.startSession();
    var state = container.read(attendanceControllerProvider);
    expect(state.phase, AttendancePhase.active);
    expect(state.sessionId, isNotNull);
    expect(state.roster, hasLength(3));
    expect(
      state.roster.every((e) => e.status == AttendanceStatus.absent),
      true,
    );

    // The first scan marks Alice present.
    await controller.submitBarcode('24BMR016');
    state = container.read(attendanceControllerProvider);
    expect(state.lastOutcome, AttendanceScanOutcome.marked);
    expect(
      state.roster.where((e) => e.status == AttendanceStatus.present),
      hasLength(1),
    );

    // Scanning the same card again is a duplicate, not a second record.
    await controller.submitBarcode('24BMR016');
    state = container.read(attendanceControllerProvider);
    expect(state.lastOutcome, AttendanceScanOutcome.alreadyPresent);

    // An unknown barcode marks nobody.
    await controller.submitBarcode('NOT-A-STUDENT');
    state = container.read(attendanceControllerProvider);
    expect(state.lastOutcome, AttendanceScanOutcome.notFound);

    final sessionId = state.sessionId!;
    await controller.finishSession();
    expect(
      container.read(attendanceControllerProvider).phase,
      AttendancePhase.finished,
    );

    // The session is frozen and reports one present, two absent.
    final bundle = await ReportService(db).buildBundle();
    expect(bundle.report.sessionCount, 1);
    expect(bundle.report.totalPresent, 1);
    expect(bundle.report.totalAbsent, 2);
    expect(
      bundle.absences.map((a) => a.rollNo),
      containsAll(<String>['24BMR017', '24BMR018']),
    );

    // Deleting the present student removes their attendance records.
    final alice = (await students.findByRollNo('24BMR016'))!;
    expect(await records.forStudent(alice.id), hasLength(1));
    await students.delete(alice.id);
    expect(await records.forStudent(alice.id), isEmpty);

    // The roster snapshot stays, so the report still knows who was expected.
    expect(await rosters.getRoster(sessionId), hasLength(3));
  });
}
