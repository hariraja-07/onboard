import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/providers.dart';
import '../attendance/models/attendance_models.dart';

/// Every stored attendance session, newest first, for the History list.
final attendanceHistoryProvider =
    FutureProvider.autoDispose<List<AttendanceSessionSummary>>((ref) async {
      final sessions = ref.watch(attendanceSessionRepositoryProvider);
      return sessions.listSessions();
    });

/// One session's frozen roster, for the History details screen.
///
/// Reads the per-session snapshot rather than the live student rows, so a
/// student edited after the session was taken still shows as they were then.
final sessionDetailsProvider = FutureProvider.autoDispose
    .family<AttendanceSessionDetails, int>((ref, sessionId) async {
      final sessions = ref.watch(attendanceSessionRepositoryProvider);
      final rosterRepository = ref.watch(
        attendanceSessionRosterRepositoryProvider,
      );
      final records = ref.watch(attendanceRecordRepositoryProvider);

      final session = await sessions.findById(sessionId);
      final roster = await rosterRepository.getRoster(sessionId);
      final presentRows = await records.forSession(sessionId);
      final presentByStudent = {
        for (final record in presentRows) record.studentId: record,
      };

      final entries =
          roster
              .map(
                (row) => AttendanceHistoryEntry(
                  sessionId: sessionId,
                  studentId: row.studentId,
                  rollNo: row.rollNo,
                  name: row.name,
                  institution: row.institution,
                  boardingPoint: row.boardingPoint,
                  status: presentByStudent.containsKey(row.studentId)
                      ? AttendanceStatus.present
                      : AttendanceStatus.absent,
                  scannedAt: presentByStudent[row.studentId]?.scannedAt,
                ),
              )
              .toList()
            ..sort((a, b) => a.rollNo.compareTo(b.rollNo));

      final total = entries.length;
      final presentCount = entries
          .where((entry) => entry.status == AttendanceStatus.present)
          .length;
      final absentCount = total - presentCount;
      final percent = total == 0 ? 0.0 : presentCount * 100.0 / total;

      final summary = AttendanceSessionSummary(
        sessionId: sessionId,
        attendanceDate: session?.attendanceDate ?? DateTime.now(),
        status: AttendanceSessionStatus.fromWireValue(
          session?.status ?? 'open',
        ),
        total: total,
        present: presentCount,
        absent: absentCount,
        percent: percent,
        startedAt: session?.createdAt,
        endedAt: session?.endedAt,
      );

      return AttendanceSessionDetails(summary: summary, entries: entries);
    });
