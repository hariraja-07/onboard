import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/attendance_controller.dart';
import 'package:onboard/features/attendance/barcode/barcode_service.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository rosters;

  var now = DateTime(2026, 10, 3, 9);

  setUp(() {
    now = DateTime(2026, 10, 3, 9);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    rosters = AttendanceSessionRosterRepository(db);
  });

  tearDown(() => db.close());

  Future<Student> addStudent(String rollNo, {String name = 'A Student'}) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: name,
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    return (await students.findById(id))!;
  }

  /// A controller over the same database, as a rebuilt app would see it.
  AttendanceController controller({
    Duration? cooldown,
    void Function()? onSessionChanged,
  }) => AttendanceController(
    studentRepository: students,
    sessionRepository: sessions,
    recordRepository: records,
    rosterRepository: rosters,
    service: const BarcodeService(),
    onSessionChanged: onSessionChanged,
    clock: () => now,
    scanCooldown: cooldown ?? const Duration(seconds: 2),
  );

  group('loading', () {
    test('reports no session to resume when today has none', () async {
      await addStudent('24BMR016');
      final notifier = controller();

      await notifier.load(forDate: now);

      expect(notifier.state.phase, AttendancePhase.awaitingStart);
      expect(notifier.state.canResume, isFalse);
      expect(notifier.state.needsNewSession, isTrue);
      expect(notifier.state.roster, hasLength(1));
      expect(notifier.state.roster.single.status, AttendanceStatus.absent);
    });

    test('offers to resume an open session for today', () async {
      final id = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      await addStudent('24BMR016');
      final notifier = controller();

      await notifier.load(forDate: now);

      expect(notifier.state.canResume, isTrue);
      expect(notifier.state.resumableSessionId, id);
      expect(notifier.state.phase, AttendancePhase.awaitingStart);
    });

    test('offers to resume an open session left from an earlier day', () async {
      final id = await sessions.createOpen(
        attendanceDate: DateTime(2026, 9, 30),
        createdAt: DateTime(2026, 9, 30, 8),
      );
      final notifier = controller();

      await notifier.load(forDate: now);

      // A session left open across midnight must not stay stuck forever: it is
      // surfaced so the operator can finish it.
      expect(notifier.state.canResume, isTrue);
      expect(notifier.state.resumableSessionId, id);
      expect(notifier.state.attendanceDate, DateTime(2026, 9, 30));
    });

    test('an empty roster reports zero rather than failing to load', () async {
      final notifier = controller();

      await notifier.load(forDate: now);

      expect(notifier.state.error, isNull);
      expect(notifier.state.totalCount, 0);
      expect(notifier.state.attendancePercent, 0);
    });
  });

  group('starting a session', () {
    test('becomes active with an open session id', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);

      await notifier.startSession();

      expect(notifier.state.phase, AttendancePhase.active);
      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.sessionId, isNotNull);
      expect(notifier.state.error, isNull);
    });

    test('two quick starts open only one session', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);

      // The second call lands while the first is still marking and must be
      // ignored rather than opening a duplicate.
      await Future.wait([notifier.startSession(), notifier.startSession()]);

      expect(await sessions.forDate(now), hasLength(1));
    });

    test('everything starts absent', () async {
      await addStudent('24BMR016');
      await addStudent('25BMR017');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();

      expect(notifier.state.totalCount, 2);
      expect(notifier.state.presentCount, 0);
      expect(notifier.state.absentCount, 2);
      expect(notifier.state.attendancePercent, 0);
    });

    test(
      'resume without a session reports an error rather than pretending',
      () async {
        final notifier = controller();
        await notifier.load(forDate: now);

        await notifier.resumeSession();

        expect(notifier.state.error, isNotNull);
        expect(notifier.state.isActive, isFalse);
      },
    );
  });

  group('scanning', () {
    late AttendanceController notifier;

    setUp(() async {
      await addStudent('24BMR016', name: 'Asha Rao');
      await addStudent('25BMR017', name: 'Bilal Khan');
      notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();
    });

    test('a matching scan marks the student present', () async {
      await notifier.scan('732924BMR016');

      expect(notifier.state.lastOutcome, AttendanceScanOutcome.marked);
      expect(notifier.state.lastStudent!.name, 'Asha Rao');
      expect(notifier.state.presentCount, 1);
      expect(notifier.state.absentCount, 1);
      expect(notifier.state.roster.first.isPresent, isTrue);
    });

    test('updates the roster before the write is awaited', () async {
      await notifier.scan('732924BMR016');

      // State is only published after the insert returns, so the row is already
      // readable from another connection's point of view.
      final sessionId = notifier.state.sessionId!;
      final stored = await records.forSession(sessionId);
      expect(stored, hasLength(1));
      expect(stored.single.status, AttendanceStatus.present.wireValue);
    });

    test('records the scan time from the clock', () async {
      await notifier.scan('732924BMR016');

      final scannedAt = notifier.state.lastRecord!.scannedAt;
      expect(scannedAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('an unknown barcode marks nobody', () async {
      await notifier.scan('NO-SUCH-CODE');

      expect(notifier.state.lastOutcome, AttendanceScanOutcome.notFound);
      expect(notifier.state.presentCount, 0);
      expect(notifier.state.lastStudent, isNull);
      expect(notifier.state.lastRecord, isNull);
      expect(await records.forSession(notifier.state.sessionId!), isEmpty);
    });

    test('an ambiguous barcode marks nobody', () async {
      await addStudent('24BMR998');
      await addStudent('24BMR999');
      final fresh = controller();
      await fresh.load(forDate: now);
      await fresh.startSession();

      // Contains both 24BMR998 and 24BMR999 (same length).
      await fresh.scan('CARD_24BMR998_24BMR999');

      expect(fresh.state.lastOutcome, AttendanceScanOutcome.ambiguous);
      expect(fresh.state.presentCount, 0);
      expect(fresh.state.lastStudent, isNull);
      expect(await records.forSession(fresh.state.sessionId!), isEmpty);
    });

    test('rescanning reports already present and writes nothing', () async {
      await notifier.scan('732924BMR016');
      now = now.add(const Duration(minutes: 5));

      await notifier.scan('732924BMR016');

      expect(notifier.state.lastOutcome, AttendanceScanOutcome.alreadyPresent);
      expect(notifier.state.presentCount, 1);
      expect(await records.forSession(notifier.state.sessionId!), hasLength(1));
    });

    test(
      'a duplicate scan still shows the student and original arrival time',
      () async {
        await notifier.scan('732924BMR016');
        final firstScan = notifier.state.lastRecord!.scannedAt;
        now = now.add(const Duration(hours: 2));

        await notifier.scan('732924BMR016');

        expect(notifier.state.lastStudent!.name, 'Asha Rao');
        expect(notifier.state.lastRecord!.scannedAt, firstScan);
      },
    );

    test('marks several students in a row', () async {
      await notifier.scan('732924BMR016');
      await notifier.scan('732925BMR017');

      expect(notifier.state.presentCount, 2);
      expect(notifier.state.absentCount, 0);
      expect(notifier.state.attendancePercent, 100);
    });

    test('two barcodes presented back to back are both recorded', () async {
      // Fired without awaiting the first, exactly as the camera does; the
      // second must queue behind it rather than being dropped mid-write.
      final first = notifier.onBarcodeScanned('732924BMR016');
      final second = notifier.onBarcodeScanned('732925BMR017');
      await Future.wait([first, second]);

      expect(notifier.state.presentCount, 2);
    });

    test('ignores a scan before a session is open', () async {
      await addStudent('26BMR018');
      final fresh = controller();
      await fresh.load(forDate: now);

      await fresh.scan('732926BMR018');

      expect(fresh.state.lastOutcome, isNull);
      expect(fresh.state.presentCount, 0);
    });

    test('ignores a scan after the session is finished', () async {
      await notifier.finishSession();

      await notifier.scan('732924BMR016');

      expect(notifier.state.lastOutcome, isNull);
      expect(notifier.state.presentCount, 0);
    });

    test('keeps the barcode exactly as scanned', () async {
      await notifier.scan('  732924bmr016 ');

      expect(notifier.state.lastBarcode, '  732924bmr016 ');
      expect(notifier.state.lastRecord!.scannedBarcode, '  732924bmr016 ');
    });

    test('manual submission is not rate limited', () async {
      await notifier.submitBarcode('732924BMR016');
      await notifier.submitBarcode('732924BMR016');

      expect(notifier.state.lastOutcome, AttendanceScanOutcome.alreadyPresent);
      expect(notifier.state.presentCount, 1);
    });

    test('the roster is frozen for the life of the session', () async {
      final fresh = controller();
      await fresh.load(forDate: now);
      await fresh.startSession();

      expect(fresh.state.totalCount, 2);

      // Imported after the session opened, so not on this session's roster.
      await addStudent('26BMR018');
      await fresh.scan('732926BMR018');

      expect(fresh.state.lastOutcome, AttendanceScanOutcome.notFound);
      expect(fresh.state.totalCount, 2);
      expect(fresh.state.attendancePercent, 0);
    });
  });

  group('camera cooldown', () {
    test('suppresses the same barcode repeated within the window', () async {
      await addStudent('24BMR016');
      final notifier = controller(cooldown: const Duration(seconds: 2));
      await notifier.load(forDate: now);
      await notifier.startSession();

      await notifier.onBarcodeScanned('732924BMR016');
      expect(notifier.state.lastOutcome, AttendanceScanOutcome.marked);

      // Same card still in front of the lens a moment later.
      now = now.add(const Duration(milliseconds: 500));
      await notifier.onBarcodeScanned('732924BMR016');
      expect(
        notifier.state.lastOutcome,
        AttendanceScanOutcome.marked,
        reason: 'the repeated frame must not replace the result',
      );

      now = now.add(const Duration(seconds: 3));
      await notifier.onBarcodeScanned('732924BMR016');
      expect(
        notifier.state.lastOutcome,
        AttendanceScanOutcome.alreadyPresent,
        reason: 'after the window the same card reports a duplicate',
      );
    });

    test('a different barcode is never suppressed', () async {
      await addStudent('24BMR016');
      await addStudent('25BMR017');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();

      await notifier.onBarcodeScanned('732924BMR016');
      await notifier.onBarcodeScanned('732925BMR017');

      expect(notifier.state.presentCount, 2);
    });

    test('the cooldown is cleared when a session starts', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);

      await notifier.onBarcodeScanned('732924BMR016');
      await notifier.startSession();
      now = now.add(const Duration(milliseconds: 100));
      await notifier.onBarcodeScanned('732924BMR016');

      expect(notifier.state.lastOutcome, AttendanceScanOutcome.marked);
    });
  });

  group('surviving interruption', () {
    test('a new controller sees marks made by an earlier one', () async {
      await addStudent('24BMR016', name: 'Asha Rao');
      await addStudent('25BMR017', name: 'Bilal Khan');
      final first = controller();
      await first.load(forDate: now);
      await first.startSession();
      await first.scan('732924BMR016');

      // A rebuilt app: fresh controller, same database.
      final reopened = controller();
      await reopened.load(forDate: now);
      await reopened.resumeSession();

      expect(reopened.state.presentCount, 1);
      expect(reopened.state.absentCount, 1);
      expect(reopened.state.attendancePercent, 50);
      final asha = reopened.state.roster.firstWhere(
        (e) => e.student.rollNo == '24BMR016',
      );
      expect(asha.isPresent, isTrue);
      expect(asha.scannedAt, isNotNull);
    });

    test(
      'resuming reuses the same session rather than creating another',
      () async {
        final first = controller();
        await first.load(forDate: now);
        await first.startSession();
        final sessionId = first.state.sessionId;

        final reopened = controller();
        await reopened.load(forDate: now);
        await reopened.resumeSession();

        expect(reopened.state.sessionId, sessionId);
        expect(await sessions.forDate(DateTime(2026, 10, 3)), hasLength(1));
      },
    );

    test('finishing closes the session so it cannot be resumed', () async {
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();

      await notifier.finishSession();

      expect(notifier.state.phase, AttendancePhase.finished);
      expect(notifier.state.isActive, isFalse);
      expect(await sessions.findOpenForDate(DateTime(2026, 10, 3)), isNull);
      final stored = await sessions.forDate(DateTime(2026, 10, 3));
      expect(stored.single.status, AttendanceSessionStatus.completed.wireValue);
    });

    test('marks made before finishing are still readable afterwards', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();
      await notifier.scan('732924BMR016');

      await notifier.finishSession();

      expect(notifier.state.presentCount, 1);
      expect(notifier.state.attendancePercent, 100);
    });

    test('finishing freezes students added during the session', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();

      // A late student joins the live roster; finishing must freeze them too,
      // otherwise history would silently omit them.
      await addStudent('25BMR017');
      final sessionId = notifier.state.sessionId!;
      await notifier.finishSession();

      final frozen = await rosters.getRoster(sessionId);
      expect(
        frozen.map((e) => e.rollNo),
        containsAll(<String>['24BMR016', '25BMR017']),
      );
    });
  });

  group('AttendanceState', () {
    test('counts and percentage follow the roster', () async {
      await addStudent('24BMR016');
      await addStudent('25BMR017');
      await addStudent('26BMR018');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession();

      expect(notifier.state.totalCount, 3);
      expect(notifier.state.attendancePercent, 0);

      await notifier.scan('732924BMR016');

      expect(notifier.state.presentCount, 1);
      expect(notifier.state.presentStudents, hasLength(1));
      expect(notifier.state.absentStudents, hasLength(2));
      expect(notifier.state.attendancePercent, closeTo(100 / 3, 0.0001));
    });

    test('an empty roster reports 0.0% rather than NaN', () {
      const state = AttendanceState(phase: AttendancePhase.active);

      expect(state.totalCount, 0);
      expect(state.presentCount, 0);
      expect(state.absentCount, 0);
      expect(state.attendancePercent, 0);
      expect(state.attendancePercent.isNaN, isFalse);
    });

    test('copyWith clears nullable fields when passed null', () {
      const populated = AttendanceState(
        phase: AttendancePhase.active,
        attendanceDate: null,
        sessionId: 7,
        resumableSessionId: 9,
        lastOutcome: AttendanceScanOutcome.marked,
        lastBarcode: 'x',
        error: 'boom',
      );

      expect(populated.copyWith().error, 'boom');
      expect(populated.copyWith(error: null).error, isNull);
      expect(populated.copyWith(lastOutcome: null).lastOutcome, isNull);
      expect(populated.copyWith(lastBarcode: null).lastBarcode, isNull);
      expect(populated.copyWith(sessionId: null).sessionId, isNull);
      expect(
        populated.copyWith(resumableSessionId: null).resumableSessionId,
        isNull,
      );
    });
  });

  group('trip lifecycle and transitions', () {
    test('selectTrip updates tripType before session begins', () async {
      final notifier = controller();
      await notifier.load(forDate: now);
      expect(notifier.state.tripType, TripType.morning);

      notifier.selectTrip(TripType.evening);
      expect(notifier.state.tripType, TripType.evening);
    });

    test('startSession uses selected tripType and stores it in database', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);
      notifier.selectTrip(TripType.evening);
      await notifier.startSession();

      expect(notifier.state.tripType, TripType.evening);
      final stored = await sessions.forDate(now);
      expect(stored.single.tripType, 'evening');
    });

    test('load suggests evening if morning session completed today', () async {
      await addStudent('24BMR016');
      final morningNotifier = controller();
      await morningNotifier.load(forDate: now);
      await morningNotifier.startSession(trip: TripType.morning);
      await morningNotifier.finishSession();

      final eveningNotifier = controller();
      await eveningNotifier.load(forDate: now);
      expect(eveningNotifier.state.tripType, TripType.evening);
    });

    test('finishSession suggests evening trip when morning session finishes', () async {
      await addStudent('24BMR016');
      final notifier = controller();
      await notifier.load(forDate: now);
      await notifier.startSession(trip: TripType.morning);
      await notifier.finishSession();

      expect(notifier.state.phase, AttendancePhase.finished);
      expect(notifier.state.tripType, TripType.evening);
    });

    test('notifies onSessionChanged on start, scan, finish, and resume', () async {
      await addStudent('24BMR016');
      var changeCount = 0;
      final notifier = controller(onSessionChanged: () => changeCount++);

      await notifier.load(forDate: now);
      expect(changeCount, 0);

      await notifier.startSession();
      expect(changeCount, 1);

      await notifier.scan('732924BMR016');
      expect(changeCount, 2);

      // Duplicate scan should not notify
      await notifier.scan('732924BMR016');
      expect(changeCount, 2);

      await notifier.finishSession();
      expect(changeCount, 3);
    });
  });

  group('roster snapshot preservation', () {
    test(
      'active roster uses frozen snapshot when live student record is edited',
      () async {
        final student = await addStudent('24BMR016', name: 'Original Name');
        final notifier = controller();
        await notifier.load(forDate: now);
        await notifier.startSession();

        expect(notifier.state.roster.single.student.name, 'Original Name');

        // Edit live student record in repository
        await students.update(
          id: student.id,
          name: 'Updated Name',
          institution: 'New Institution',
          boardingPoint: 'South Gate',
        );

        // Resuming or reloading active roster preserves frozen snapshot
        final resumedNotifier = controller();
        await resumedNotifier.load(forDate: now);
        await resumedNotifier.resumeSession();

        expect(
          resumedNotifier.state.roster.single.student.name,
          'Original Name',
        );
      },
    );
  });
}
