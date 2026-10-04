import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/attendance_session_repository.dart';
import '../../core/database/repositories/student_repository.dart';
import '../attendance/models/attendance_models.dart';
import '../reports/report_service.dart';

/// Everything the Dashboard shows, loaded in one pass.
class DashboardData {
  const DashboardData({
    required this.studentCount,
    required this.allTime,
    required this.todaySessions,
    required this.recentSessions,
  });

  final int studentCount;
  final AttendanceReport allTime;
  final List<AttendanceSessionSummary> todaySessions;

  /// The most recent sessions across all time (already newest-first).
  final List<AttendanceSessionSummary> recentSessions;

  bool get hasAttendance => allTime.totalPresent > 0;

  /// The most recent session today, or null if none was taken.
  AttendanceSessionSummary? get latestToday =>
      todaySessions.isEmpty ? null : todaySessions.first;

  /// Morning session today, if any.
  AttendanceSessionSummary? get morningToday {
    for (final s in todaySessions) {
      if (s.tripType == TripType.morning) return s;
    }
    return null;
  }

  /// Evening session today, if any.
  AttendanceSessionSummary? get eveningToday {
    for (final s in todaySessions) {
      if (s.tripType == TripType.evening) return s;
    }
    return null;
  }
}

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(databaseProvider));
});

/// Reloaded after attendance changes so the numbers stay current.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  return ref.watch(dashboardServiceProvider).load();
});

class DashboardService {
  DashboardService(this.db);

  final AppDatabase db;

  static const int recentLimit = 5;

  Future<DashboardData> load() async {
    final now = DateTime.now();
    final repository = AttendanceSessionRepository(db);

    final students = await StudentRepository(db).getAll();
    final allTime = await ReportService(db).build();
    final todaySessions = await repository.listSessions(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day),
      limit: null,
    );

    return DashboardData(
      studentCount: students.length,
      allTime: allTime,
      todaySessions: todaySessions,
      recentSessions: allTime.sessions.take(recentLimit).toList(),
    );
  }
}
