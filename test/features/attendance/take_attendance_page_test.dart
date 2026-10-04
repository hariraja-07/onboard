import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/attendance_controller.dart';
import 'package:onboard/features/attendance/barcode/barcode_service.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onboard/features/attendance/pages/take_attendance_page.dart';

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
  });

  tearDown(() => db.close());

  Future<void> seedStudent(String rollNo, String name) async {
    await students.insert(
      rollNo: rollNo,
      name: name,
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
  }

  Widget createSubject({AttendanceController? controller, bool? tickersEnabled}) {
    Widget page = const TakeAttendancePage();
    if (tickersEnabled != null) {
      page = TickerMode(enabled: tickersEnabled, child: page);
    }
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        studentRepositoryProvider.overrideWithValue(students),
        attendanceSessionRepositoryProvider.overrideWithValue(sessions),
        attendanceRecordRepositoryProvider.overrideWithValue(records),
        attendanceSessionRosterRepositoryProvider.overrideWithValue(rosters),
        if (controller != null)
          attendanceControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        home: page,
      ),
    );
  }

  AttendanceController buildController() => AttendanceController(
    studentRepository: students,
    sessionRepository: sessions,
    recordRepository: records,
    rosterRepository: rosters,
    service: const BarcodeService(),
  );

    testWidgets('renders filter segmented button with All, Present, Absent and search field', (
    tester,
  ) async {
    await seedStudent('24BMR016', 'Alice');

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Take Attendance'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Start Morning Session'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shows Start Next Session and Reload after session finishes (no deadlock)', (
    tester,
  ) async {
    await seedStudent('24BMR016', 'Alice');

    final controller = AttendanceController(
      studentRepository: students,
      sessionRepository: sessions,
      recordRepository: records,
      rosterRepository: rosters,
      service: const BarcodeService(),
    );

    await tester.pumpWidget(createSubject(controller: controller));
    await tester.pumpAndSettle();

    // Start morning session
    await tester.tap(find.text('Start Morning Session'));
    await tester.pumpAndSettle();

    expect(find.text('Finish (Morning)'), findsOneWidget);
    expect(find.text('Attendance • Morning'), findsOneWidget);

    // Finish morning session
    await tester.tap(find.text('Finish (Morning)'));
    await tester.pumpAndSettle();

    // Deadlock is resolved: buttons for next session and reload are present
    expect(find.text('Start Evening Session'), findsOneWidget);
    expect(find.byTooltip('Reload'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('allows manual barcode submission via search field when session is active', (
    tester,
  ) async {
    await seedStudent('24BMR016', 'Alice');

    final controller = AttendanceController(
      studentRepository: students,
      sessionRepository: sessions,
      recordRepository: records,
      rosterRepository: rosters,
      service: const BarcodeService(),
    );

    await tester.pumpWidget(createSubject(controller: controller));
    await tester.pumpAndSettle();

    // Start session
    await tester.tap(find.text('Start Morning Session'));
    await tester.pumpAndSettle();

    // Type barcode and submit
    await tester.enterText(find.byType(TextField), '24BMR016');
    await tester.pumpAndSettle();

    // Submit via send button
    expect(find.byTooltip('Submit barcode'), findsOneWidget);
    await tester.tap(find.byTooltip('Submit barcode'));
    await tester.pumpAndSettle();

    // Student marked present
    expect(find.text('Attendance Marked'), findsOneWidget);
    expect(find.textContaining('Alice'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('allows tapping an absent student card in roster to mark attendance', (
    tester,
  ) async {
    await seedStudent('24BMR016', 'Alice');

    final controller = AttendanceController(
      studentRepository: students,
      sessionRepository: sessions,
      recordRepository: records,
      rosterRepository: rosters,
      service: const BarcodeService(),
    );

    await tester.pumpWidget(createSubject(controller: controller));
    await tester.pumpAndSettle();

    // Start morning session
    await tester.tap(find.text('Start Morning Session'));
    await tester.pumpAndSettle();

    // Tap Alice in the roster
    expect(find.text('Alice'), findsOneWidget);
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    // Student marked present
    expect(find.text('Attendance Marked'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  group('shouldRunScanner', () {
    test('runs only when the session is active and the tab is visible', () {
      expect(
        shouldRunScanner(isActive: true, isTabVisible: true),
        isTrue,
      );
      // Offstage tabs and finished sessions must both release the camera.
      expect(
        shouldRunScanner(isActive: true, isTabVisible: false),
        isFalse,
      );
      expect(
        shouldRunScanner(isActive: false, isTabVisible: true),
        isFalse,
      );
      expect(
        shouldRunScanner(isActive: false, isTabVisible: false),
        isFalse,
      );
    });
  });

  group('pausing from the camera overlay', () {
    testWidgets('offers Pause only while a session is active', (tester) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsNothing);

      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('pausing shows a resume overlay and keeps Finish reachable', (
      tester,
    ) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(find.text('Scanning paused'), findsOneWidget);
      expect(find.text('Tap to resume'), findsOneWidget);
      // The old copy claimed the scanner was paused because the session was
      // inactive; that is no longer what happens.
      expect(find.textContaining('session inactive'), findsNothing);
      // Finish stays available so a paused session is not a dead end.
      expect(find.text('Finish (Morning)'), findsOneWidget);
      // The title keeps identifying the live session.
      expect(find.text('Attendance • Morning'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping the overlay resumes and restores the reticle', (
      tester,
    ) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tap(find.text('Tap to resume'));
      await tester.pumpAndSettle();

      expect(find.text('Scanning paused'), findsNothing);
      expect(find.text('Tap to resume'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('a stopped camera cannot be driven by torch or flip', (
      tester,
    ) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();

      // find.byTooltip resolves to the tooltip wrapper, so reach the button
      // through it.
      IconButton switchCamera() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Switch camera'),
          matching: find.byType(IconButton),
        ),
      );
      expect(switchCamera().onPressed, isNotNull);

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(switchCamera().onPressed, isNull);
      expect(controller.state.phase, AttendancePhase.paused);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('an offstage tab reports a stopped scanner, not a paused one', (
      tester,
    ) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      // tickersEnabled: false mirrors the offstage branch of the indexed
      // shell, which keeps the page alive but muted.
      await tester.pumpWidget(
        createSubject(controller: controller, tickersEnabled: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();

      expect(controller.state.isActive, isTrue);
      expect(find.text('Scanner stopped'), findsOneWidget);
      expect(find.text('Start or resume a session to scan'), findsOneWidget);
      // Not resumable, so it must not offer a resume affordance.
      expect(find.text('Tap to resume'), findsNothing);
      expect(find.text('Pause'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // The overlay copy has to fit a 220dp-tall preview, so doubling the text is
    // what stresses it. The surface is wide enough for the pre-existing
    // _SessionActions row, which needs ~964dp at 2x text, so takeException
    // stays meaningful instead of reporting that unrelated overflow.
    testWidgets('the paused overlay copy still fits the preview at a large text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(find.text('Scanning paused'), findsOneWidget);
      final preview = tester.getSize(find.byType(MobileScanner));
      final overlayCopy = tester.getSize(find.byType(FittedBox));
      expect(
        overlayCopy.height,
        lessThanOrEqualTo(preview.height),
        reason: 'the overlay must scale its copy rather than overflow the preview',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('scan haptics', () {
    // Every haptic the page asks for, in order. The switch that maps an
    // outcome to a buzz has no break statements, so without an explicit break
    // a single mark falls through and fires every later case.
    List<String> recordHaptics(WidgetTester tester) {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return haptics;
    }

    Future<void> submitBarcode(WidgetTester tester, String barcode) async {
      await tester.enterText(find.byType(TextField), barcode);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Submit barcode'));
      await tester.pumpAndSettle();
    }

    testWidgets('one mark buzzes once, a re-presented card stays silent', (
      tester,
    ) async {
      await seedStudent('24BMR016', 'Alice');
      final controller = buildController();
      final haptics = recordHaptics(tester);

      await tester.pumpWidget(createSubject(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Morning Session'));
      await tester.pumpAndSettle();

      await submitBarcode(tester, '24BMR016');
      expect(controller.state.lastOutcome, AttendanceScanOutcome.marked);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);

      // A different spelling of the same card clears the cooldown but resolves
      // to the same student, which is how alreadyPresent is reached here.
      await submitBarcode(tester, '732924BMR016');
      expect(controller.state.lastOutcome, AttendanceScanOutcome.alreadyPresent);
      expect(
        haptics,
        ['HapticFeedbackType.mediumImpact'],
        reason: 'a card already marked must not buzz again',
      );

      // An unrecognised card is still worth one buzz, and only one.
      await submitBarcode(tester, 'no-such-card');
      expect(controller.state.lastOutcome, AttendanceScanOutcome.notFound);
      expect(haptics, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
