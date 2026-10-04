import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  Widget createSubject({AttendanceController? controller}) {
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
      child: const MaterialApp(
        home: TakeAttendancePage(),
      ),
    );
  }

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
}
