import '../database/database.dart';

/// A problem with a backup file that the user can act on.
///
/// Carries a message written for the operator, not a stack trace: every throw
/// site is a file-shaped problem (wrong format, newer version, missing field)
/// rather than an internal failure.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything a backup holds, in memory.
///
/// Rows are the generated Drift classes so the data maps one-to-one onto the
/// tables; [encode] and [decodeAndValidate] on `BackupService` are the only
/// places that know the JSON shape.
class BackupData {
  const BackupData({
    required this.formatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.students,
    required this.sessions,
    required this.records,
    required this.roster,
    this.settings = const {},
  });

  final int formatVersion;
  final String appVersion;
  final int schemaVersion;
  final DateTime exportedAt;

  final List<Student> students;
  final List<AttendanceSession> sessions;
  final List<AttendanceRecord> records;
  final List<AttendanceSessionRosterData> roster;

  /// Reserved for application settings. Empty until a settings store exists;
  /// carrying the field now means a later settings store is backed up and
  /// restored without a format change.
  final Map<String, Object?> settings;

  int get studentCount => students.length;
  int get sessionCount => sessions.length;
  int get recordCount => records.length;
  int get rosterCount => roster.length;

  BackupInfo get info => BackupInfo(
    formatVersion: formatVersion,
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    exportedAt: exportedAt,
    studentCount: studentCount,
    sessionCount: sessionCount,
    recordCount: recordCount,
    rosterCount: rosterCount,
    earliestSession: _earliestSession(),
    latestSession: _latestSession(),
  );

  DateTime? _earliestSession() {
    if (sessions.isEmpty) return null;
    var earliest = sessions.first.attendanceDate;
    for (final session in sessions) {
      if (session.attendanceDate.isBefore(earliest)) {
        earliest = session.attendanceDate;
      }
    }
    return earliest;
  }

  DateTime? _latestSession() {
    if (sessions.isEmpty) return null;
    var latest = sessions.first.attendanceDate;
    for (final session in sessions) {
      if (session.attendanceDate.isAfter(latest)) {
        latest = session.attendanceDate;
      }
    }
    return latest;
  }
}

/// What a backup contains, shown before the user is asked to restore it.
class BackupInfo {
  const BackupInfo({
    required this.formatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.studentCount,
    required this.sessionCount,
    required this.recordCount,
    required this.rosterCount,
    this.earliestSession,
    this.latestSession,
  });

  final int formatVersion;
  final String appVersion;
  final int schemaVersion;
  final DateTime exportedAt;
  final int studentCount;
  final int sessionCount;
  final int recordCount;
  final int rosterCount;
  final DateTime? earliestSession;
  final DateTime? latestSession;
}
