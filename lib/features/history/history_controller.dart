import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_service.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/attendance_session_repository.dart';
import '../attendance/models/attendance_models.dart';
import '../dashboard/dashboard_service.dart';
import '../reports/report_service.dart';
import '../settings/backup_file_gateway.dart';
import '../settings/safety_backup.dart';

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
        tripType: session != null
            ? TripType.fromWireValue(session.tripType)
            : TripType.morning,
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

/// Where a History mutation currently is.
class HistoryMutationState {
  const HistoryMutationState({this.isBusy = false, this.message, this.error});

  final bool isBusy;

  /// A success/info line to show the user once.
  final String? message;

  /// A failure line to show the user once.
  final String? error;
}

/// Drives the destructive actions on the History screens.
final historyMutationProvider =
    StateNotifierProvider<HistoryMutationController, HistoryMutationState>((
      ref,
    ) {
      return HistoryMutationController(
        sessionRepository: ref.watch(attendanceSessionRepositoryProvider),
        backupService: ref.watch(backupServiceProvider),
        gateway: ref.watch(backupFileGatewayProvider),
        reloadData: () {
          ref.invalidate(attendanceHistoryProvider);
          ref.invalidate(sessionDetailsProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(attendanceReportProvider);
        },
      );
    });

/// Deletes attendance sessions from History and the session details screen.
class HistoryMutationController extends StateNotifier<HistoryMutationState> {
  HistoryMutationController({
    required AttendanceSessionRepository sessionRepository,
    required BackupService backupService,
    required BackupFileGateway gateway,
    required void Function() reloadData,
  }) : _sessions = sessionRepository,
       _backup = backupService,
       _gateway = gateway,
       _reloadData = reloadData,
       super(const HistoryMutationState());

  final AttendanceSessionRepository _sessions;
  final BackupService _backup;
  final BackupFileGateway _gateway;
  final void Function() _reloadData;

  /// Deletes one session along with its records and roster snapshot.
  ///
  /// A safety copy of the whole database is written first, so an accidental
  /// delete can be undone from Settings. If that copy cannot be written the
  /// session is left alone: refusing to delete is an annoyance, whereas
  /// silently destroying a day's attendance is not recoverable.
  ///
  /// Returns the resulting state, so the caller can report what happened
  /// without having to watch [state] for it.
  Future<HistoryMutationState> deleteSession(
    AttendanceSessionSummary summary,
  ) async {
    if (state.isBusy) return state;
    state = const HistoryMutationState(isBusy: true);

    try {
      final safetyPath = await writeSafetyBackup(_backup, _gateway);
      await _sessions.deleteSession(summary.sessionId);
      _reloadData();
      state = HistoryMutationState(
        message:
            'Deleted the ${summary.tripType.label} session for '
            '${formatHistoryDate(summary.attendanceDate)}.\n'
            'A safety copy was saved to $safetyPath',
      );
      return state;
    } catch (error) {
      state = HistoryMutationState(
        error: 'Could not delete the session, so nothing was changed.\n$error',
      );
      return state;
    }
  }

  /// Clears the last message or error line.
  void acknowledge() => state = const HistoryMutationState();
}

/// Formats a session date the way both History screens show it.
String formatHistoryDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
