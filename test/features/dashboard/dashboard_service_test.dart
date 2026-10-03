import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/attendance_record_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_repository.dart';
import 'package:onboard/core/database/repositories/attendance_session_roster_repository.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/dashboard/dashboard_service.dart';

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late AttendanceSessionRepository sessions;
  late AttendanceRecordRepository records;
  late AttendanceSessionRosterRepository rosters;
  late DashboardService dashboard;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    sessions = AttendanceSessionRepository(db);
    records = AttendanceRecordRepository(db);
    rosters = AttendanceSessionRosterRepository(db);
    dashboard = DashboardService(db);
  });

  tearDown(() => db.close());

  Future<Student> addStudent(String rollNo, String name) async {
    final id = await students.insert(
      rollNo: rollNo,
      name: name,
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    return (await students.findById(id))!;
  }

  test('empty database reports zeroes without throwing', () async {
    final data = await dashboard.load();

    expect(data.studentCount, 0);
    expect(data.allTime.sessionCount, 0);
    expect(data.allTime.overallPercent, 0);
    expect(data.todaySessions, isEmpty);
    expect(data.recentSessions, isEmpty);
    expect(data.latestToday, isNull);
    expect(data.hasAttendance, isFalse);
  });

  test('summarises students, all-time totals and today', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alice = await addStudent('24BMR016', 'Alice');
    final bob = await addStudent('24BMR017', 'Bob');

    final yesterday = await sessions.createOpen(
      attendanceDate: today.subtract(const Duration(days: 1)),
      createdAt: today.subtract(const Duration(days: 1)),
    );
    await rosters.insertRoster(yesterday, [alice]);
    await records.markPresent(
      sessionId: yesterday,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: today.subtract(const Duration(days: 1)),
    );

    final todays = await sessions.createOpen(
      attendanceDate: today,
      createdAt: today,
    );
    await rosters.insertRoster(todays, [alice, bob]);
    await records.markPresent(
      sessionId: todays,
      student: alice,
      rawBarcode: '24BMR016',
      scannedAt: today,
    );

    final data = await dashboard.load();

    expect(data.studentCount, 2);
    expect(data.allTime.sessionCount, 2);
    expect(data.allTime.totalPresent, 2);
    expect(data.allTime.totalAbsent, 1);

    expect(data.todaySessions.map((s) => s.sessionId), [todays]);
    expect(data.latestToday!.sessionId, todays);
    expect(data.recentSessions.first.sessionId, todays);
    expect(data.hasAttendance, isTrue);
  });
}
