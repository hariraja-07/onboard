import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onboard/core/backup/backup_service.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/history/history_controller.dart';
import 'package:onboard/features/history/pages/history_page.dart';
import 'package:onboard/features/history/pages/session_details_page.dart';
import 'package:onboard/features/settings/backup_file_gateway.dart';
import 'package:onboard/features/settings/safety_backup.dart';

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

    test('preserves tripType for morning and evening sessions', () async {
      final morningId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        tripType: 'morning',
        createdAt: DateTime(2026, 10, 3, 8),
      );
      await sessions.complete(morningId);

      await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        tripType: 'evening',
        createdAt: DateTime(2026, 10, 3, 16),
      );

      final summaries = await sessions.listSessions();
      expect(summaries, hasLength(2));
      expect(summaries.map((s) => s.tripType), containsAll([TripType.morning, TripType.evening]));
    });

    test('filters by date range and still counts each session', () async {
      final older = await sessions.createOpen(
        attendanceDate: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 9, 1, 8),
      );
      final newer = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        createdAt: DateTime(2026, 10, 3, 8),
      );
      final alice = await addStudent('24BMR016', name: 'Alice');
      final bob = await addStudent('24BMR017', name: 'Bob');
      await rosters.insertRoster(older, [alice]);
      await rosters.insertRoster(newer, [alice, bob]);
      await records.markPresent(
        sessionId: newer,
        student: alice,
        rawBarcode: '24BMR016',
        scannedAt: DateTime(2026, 10, 3, 9),
      );

      final october = await sessions.listSessions(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );
      expect(october.map((s) => s.sessionId), [newer]);
      expect(october.single.total, 2);
      expect(october.single.present, 1);
      expect(october.single.absent, 1);
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

    test(
      'deleting a student purges them from historical roster snapshots and summaries',
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

        // Delete Bob completely
        await students.delete(bob.id);

        final details = await container().read(
          sessionDetailsProvider(sessionId).future,
        );
        expect(details.entries.map((e) => e.rollNo), ['24BMR016']);
        expect(details.summary.total, 1);
        expect(details.summary.present, 1);
        expect(details.summary.absent, 0);
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

  testWidgets('AttendanceHistoryPage renders mobile cards for sessions', (
    tester,
  ) async {
    final sessionId = await sessions.createOpen(
      attendanceDate: DateTime(2026, 10, 3),
      createdAt: DateTime(2026, 10, 3, 8),
    );
    final alice = await addStudent('24BMR016', name: 'Alice');
    await rosters.insertRoster(sessionId, [alice]);
    await records.markPresent(
      sessionId: sessionId,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: DateTime(2026, 10, 3, 8, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceSessionRepositoryProvider.overrideWithValue(sessions),
          attendanceRecordRepositoryProvider.overrideWithValue(records),
          attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
        ],
        child: const MaterialApp(
          home: AttendanceHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendance History'), findsOneWidget);
    expect(find.textContaining('Morning'), findsWidgets);
    expect(find.text('1/1 present'), findsOneWidget);
    expect(find.text('View Roster'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  group('deleting a session', () {
    /// A session with one marked student, so a delete has records to cascade.
    Future<int> seedMarkedSession() async {
      final sessionId = await sessions.createOpen(
        attendanceDate: DateTime(2026, 10, 3),
        tripType: 'morning',
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
      await sessions.complete(sessionId);
      return sessionId;
    }

    ProviderContainer mutationContainer(FakeGateway gateway) {
      final value = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          attendanceSessionRepositoryProvider.overrideWithValue(sessions),
          attendanceRecordRepositoryProvider.overrideWithValue(records),
          attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
          backupServiceProvider.overrideWith((ref) => BackupService(db)),
          backupFileGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(value.dispose);
      return value;
    }

    test('removes the session with its records and roster snapshot', () async {
      final sessionId = await seedMarkedSession();
      final summary = (await sessions.listSessions()).single;
      expect(summary.present, 1);

      final gateway = FakeGateway();
      final result = await mutationContainer(gateway)
          .read(historyMutationProvider.notifier)
          .deleteSession(summary);

      expect(result.error, isNull);
      expect(result.message, contains('Deleted the Morning session'));
      expect(result.message, contains('2026-10-03'));
      expect(await sessions.findById(sessionId), isNull);
      expect(await records.forSession(sessionId), isEmpty);
      expect(await rosters.getRoster(sessionId), isEmpty);
      expect(await sessions.listSessions(), isEmpty);
    });

    test('writes the safety copy before anything is deleted', () async {
      final sessionId = await seedMarkedSession();
      final summary = (await sessions.listSessions()).single;
      var existedWhenBackupWasWritten = false;

      final gateway = FakeGateway(
        onWrite: () async {
          existedWhenBackupWasWritten = await sessions.findById(sessionId) != null;
        },
      );
      await mutationContainer(gateway)
          .read(historyMutationProvider.notifier)
          .deleteSession(summary);

      expect(gateway.safetyWrites, 1);
      expect(
        existedWhenBackupWasWritten,
        isTrue,
        reason: 'the safety copy must contain the session being deleted',
      );
      expect(gateway.safetyBytes, isNotNull);
      expect(await sessions.findById(sessionId), isNull);
    });

    test('keeps the session when the safety copy cannot be written', () async {
      final sessionId = await seedMarkedSession();
      final summary = (await sessions.listSessions()).single;
      final gateway = FakeGateway()..safetyBackupThrows = true;

      final result = await mutationContainer(gateway)
          .read(historyMutationProvider.notifier)
          .deleteSession(summary);

      expect(result.message, isNull);
      expect(result.error, contains('nothing was changed'));
      expect(result.error, contains('no space left on device'));
      expect(await sessions.findById(sessionId), isNotNull);
      expect(await records.forSession(sessionId), hasLength(1));
    });

    testWidgets('asks first, and cancelling leaves the session alone', (
      tester,
    ) async {
      final sessionId = await seedMarkedSession();
      final gateway = FakeGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            attendanceSessionRepositoryProvider.overrideWithValue(sessions),
            attendanceRecordRepositoryProvider.overrideWithValue(records),
            attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
            backupServiceProvider.overrideWith((ref) => BackupService(db)),
            backupFileGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(home: AttendanceHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Session actions'));
      await tester.pumpAndSettle();
      expect(find.text('Delete session'), findsOneWidget);

      await tester.tap(find.text('Delete session'));
      await tester.pumpAndSettle();

      // The confirmation has to name the session and say what goes with it.
      expect(find.text('Delete this session?'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('2026-10-03 morning session'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('1 attendance record'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(gateway.safetyWrites, 0);
      expect(await sessions.findById(sessionId), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('the details screen deletes the session and leaves it', (
      tester,
    ) async {
      final sessionId = await seedMarkedSession();
      final gateway = FakeGateway();

      // A real router, because the screen pops itself once the session behind
      // it is gone. Starting on the list and pushing matches how the screen is
      // actually reached, which is also the only way there is something to pop
      // back to.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('History list'))),
          ),
          GoRoute(
            path: '/history/:id',
            builder: (context, state) => AttendanceSessionDetailsPage(
              sessionId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            attendanceSessionRepositoryProvider.overrideWithValue(sessions),
            attendanceRecordRepositoryProvider.overrideWithValue(records),
            attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
            backupServiceProvider.overrideWith((ref) => BackupService(db)),
            backupFileGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('History list'), findsOneWidget);

      router.push('/history/$sessionId');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete session'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await sessions.findById(sessionId), isNull);
      expect(gateway.safetyWrites, 1);
      // Nothing is left to show on a session that no longer exists.
      expect(find.text('History list'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('confirming deletes the session and says so', (tester) async {
      final sessionId = await seedMarkedSession();
      final gateway = FakeGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            attendanceSessionRepositoryProvider.overrideWithValue(sessions),
            attendanceRecordRepositoryProvider.overrideWithValue(records),
            attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
            backupServiceProvider.overrideWith((ref) => BackupService(db)),
            backupFileGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(home: AttendanceHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Session actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await sessions.findById(sessionId), isNull);
      expect(gateway.safetyWrites, 1);
      expect(find.text('No attendance sessions yet'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Deleted the Morning session'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}

/// Records what the controller asked the gateway to do, and can be told to
/// fail, so that the safety-copy-first ordering is actually observable.
///
/// Declared at file level like the other fakes in this suite: the analyzer in
/// this SDK fails to parse a class declared inside a local function body.
class FakeGateway implements BackupFileGateway {
  FakeGateway({this.onWrite});

  /// Runs at the moment the safety copy is written, which is the only way to
  /// tell whether the session still existed at that point.
  final Future<void> Function()? onWrite;

  bool safetyBackupThrows = false;
  int safetyWrites = 0;
  Uint8List? safetyBytes;

  @override
  Future<String> writeSafetyBackup(Uint8List bytes, String fileName) async {
    safetyWrites++;
    if (safetyBackupThrows) throw StateError('no space left on device');
    safetyBytes = bytes;
    await onWrite?.call();
    return '/backups/$fileName';
  }

  @override
  Future<PickedBackup?> pickBackup() async => null;

  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async => null;

  @override
  Future<String?> saveExport(Uint8List bytes, String fileName) async => null;
}
