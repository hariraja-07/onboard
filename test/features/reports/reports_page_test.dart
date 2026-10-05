import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/reports/pages/reports_page.dart';
import 'package:onboard/features/settings/backup_file_gateway.dart';
import 'package:onboard/features/settings/safety_backup.dart';

/// The two students every seeded session shares.
///
/// Created per test rather than per test file, since each test gets a fresh
/// in-memory database and roll_no is unique.
List<Student>? sharedRoster;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    sharedRoster = null;
  });

  tearDown(() => db.close());

  Future<Student> addStudent(String rollNo, String name) => students.insert(
    rollNo: rollNo,
    name: name,
    institution: 'Springfield College',
    boardingPoint: 'North Gate',
  ).then((id) async => (await students.findById(id))!);

  /// The two students every seeded session shares, created once per test.
  Future<List<Student>> loadRoster() async =>
      sharedRoster ??= [
        await addStudent('24BMR016', 'Alice'),
        await addStudent('24BMR017', 'Bob'),
      ];

  /// One completed session on [date] for [trip], with [present] of two marked.
  ///
  /// The two students are created once and reused across sessions, since
  /// roll_no is unique and a day's two trips share one roster.
  Future<int> seedSession({
    required DateTime date,
    required TripType trip,
    required int present,
  }) async {
    final sessionId = await sessions.createOpen(
      attendanceDate: date,
      tripType: trip.wireValue,
      createdAt: date.add(const Duration(hours: 8)),
    );
    final roster = await loadRoster();
    await rosters.insertRoster(sessionId, roster);
    for (final student in roster.take(present)) {
      await records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: student.rollNo,
        scannedAt: date.add(const Duration(hours: 9)),
      );
    }
    await sessions.complete(sessionId, date.add(const Duration(hours: 10)));
    return sessionId;
  }

  Widget subject({FakeGateway? gateway}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      attendanceSessionRepositoryProvider.overrideWithValue(sessions),
      attendanceRecordRepositoryProvider.overrideWithValue(records),
      attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
      backupFileGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
    ],
    child: const MaterialApp(home: ReportsPage()),
  );

  /// The same page inside a router, for the test that taps the row itself.
  Widget routedSubject({FakeGateway? gateway}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ReportsPage()),
        GoRoute(
          path: '/history/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('Session ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        attendanceSessionRepositoryProvider.overrideWithValue(sessions),
        attendanceRecordRepositoryProvider.overrideWithValue(records),
        attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
        backupFileGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void useSmallScreen(WidgetTester tester, {double textScale = 1.0}) {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  group('filter layout', () {
    testWidgets('offers a date row and a trip row', (tester) async {
      await seedSession(
        date: DateTime.now(),
        trip: TripType.morning,
        present: 2,
      );

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Last week'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('All trips'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
    });

    testWidgets('the trip filter combines with a date filter', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await seedSession(
        date: today,
        trip: TripType.morning,
        present: 2,
      );
      await seedSession(
        date: today,
        trip: TripType.evening,
        present: 1,
      );

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.textContaining('2/2 present'), findsOneWidget);
      expect(find.textContaining('1/2 present'), findsOneWidget);

      // All trips is the default, so both sessions are listed.
      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2/2 present'),
        findsOneWidget,
        reason: 'the morning session stays',
      );
      expect(
        find.textContaining('1/2 present'),
        findsNothing,
        reason: 'the evening session is filtered out',
      );
    });

    testWidgets('both filter rows fit a 320-wide screen', (tester) async {
      await seedSession(
        date: DateTime.now(),
        trip: TripType.morning,
        present: 2,
      );
      useSmallScreen(tester);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Evening'), findsOneWidget);
    });

    testWidgets('an empty result names the active filters', (tester) async {
      await seedSession(
        date: DateTime(2026, 1, 5),
        trip: TripType.morning,
        present: 2,
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('No sessions match these filters'), findsOneWidget);
      expect(find.textContaining('All time'), findsNothing);
      expect(
        find.textContaining(formatDateForTest(today)),
        findsOneWidget,
        reason: 'the empty state should say which day it looked at',
      );
    });
  });

  group('session list', () {
    testWidgets('shows no analysis and no absences list', (tester) async {
      await seedSession(
        date: DateTime.now(),
        trip: TripType.morning,
        present: 1,
      );

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('Sessions (1)'), findsOneWidget);
      // The summary stat cards are gone.
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Expected'), findsNothing);
      expect(find.textContaining('Attendance %'), findsNothing);
      // So is the on-screen absences section.
      expect(find.textContaining('Absences'), findsNothing);
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('gives every session an export button', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await seedSession(date: today, trip: TripType.morning, present: 2);
      await seedSession(date: today, trip: TripType.evening, present: 1);

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Export this session'), findsNWidgets(2));
    });
  });

  group('per-session export', () {
    testWidgets('writes one workbook named after that session', (
      tester,
    ) async {
      final sessionId = await seedSession(
        date: DateTime(2026, 10, 5),
        trip: TripType.evening,
        present: 1,
      );
      final gateway = FakeGateway();

      await tester.pumpWidget(subject(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export this session'));
      await tester.pumpAndSettle();

      expect(gateway.exportedNames, [
        'onboard_attendance_2026-10-05_evening.xlsx',
      ]);
      expect(gateway.exportedBytes, hasLength(1));
      expect(
        gateway.exportedBytes.single.take(2),
        [0x50, 0x4B],
        reason: 'a real xlsx archive',
      );
      expect(sessionId, isPositive);
    });

    testWidgets('a cancelled export is reported, not treated as saved', (
      tester,
    ) async {
      await seedSession(
        date: DateTime(2026, 10, 5),
        trip: TripType.morning,
        present: 2,
      );
      final gateway = FakeGateway(cancelExports: true);

      await tester.pumpWidget(subject(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export this session'));
      await tester.pumpAndSettle();

      expect(find.text('Export cancelled.'), findsOneWidget);
      expect(find.byTooltip('Export this session'), findsOneWidget);
    });

    testWidgets('one export does not disable the other rows', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await seedSession(date: today, trip: TripType.morning, present: 2);
      await seedSession(date: today, trip: TripType.evening, present: 1);
      final gateway = FakeGateway();

      await tester.pumpWidget(subject(gateway: gateway));
      await tester.pumpAndSettle();

      final buttons = find.byTooltip('Export this session');
      await tester.tap(buttons.at(0));
      await tester.pumpAndSettle();

      expect(gateway.exportedNames, hasLength(1));
      expect(
        buttons,
        findsNWidgets(2),
        reason: 'both rows stay tappable after an export finishes',
      );
    });

testWidgets('the row opens the session and exports nothing', (tester) async {
      final sessionId = await seedSession(
        date: DateTime(2026, 10, 5),
        trip: TripType.morning,
        present: 2,
      );
      final gateway = FakeGateway();

      await tester.pumpWidget(routedSubject(gateway: gateway));
      await tester.pumpAndSettle();

      // Matched on the row title so it cannot also hit the Morning trip chip.
      await tester.tap(find.text('2026-10-05 · Morning'));
      await tester.pumpAndSettle();

      expect(find.text('Session $sessionId'), findsOneWidget);
      expect(
        gateway.exportedNames,
        isEmpty,
        reason: 'navigating must not be the same gesture as exporting',
      );
    });
  });
}

/// The date format the report screen uses, kept local so the assertion cannot
/// drift if the service's formatter changes.
String formatDateForTest(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class FakeGateway implements BackupFileGateway {
  FakeGateway({this.cancelExports = false});

  final bool cancelExports;

  final exportedNames = <String>[];
  final exportedBytes = <Uint8List>[];

  @override
  Future<String?> saveExport(Uint8List bytes, String fileName) async {
    if (cancelExports) return null;
    exportedNames.add(fileName);
    exportedBytes.add(bytes);
    return '/exports/$fileName';
  }

  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async => null;

  @override
  Future<PickedBackup?> pickBackup() async => null;

  @override
  Future<String> writeSafetyBackup(Uint8List bytes, String fileName) async =>
      '/backups/$fileName';
}