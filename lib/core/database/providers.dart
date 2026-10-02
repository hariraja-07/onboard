import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'repositories/student_repository.dart';
import 'repositories/attendance_session_repository.dart';
import 'repositories/attendance_record_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(databaseProvider));
});

final attendanceSessionRepositoryProvider = Provider<AttendanceSessionRepository>((ref) {
  return AttendanceSessionRepository(ref.watch(databaseProvider));
});

final attendanceRecordRepositoryProvider = Provider<AttendanceRecordRepository>((ref) {
  return AttendanceRecordRepository(ref.watch(databaseProvider));
});