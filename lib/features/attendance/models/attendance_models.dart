import '../../../core/database/database.dart';

/// Whether a student was counted as attending a session.
///
/// PRESENT is persisted on `attendance_records` when a card is scanned.
/// ABSENT is never written to the database: it is derived as
/// (every registered student) minus (every student with a record in this
/// session). Reports that want "who was absent on date X" must compute that
/// difference rather than filtering `WHERE status = 'ABSENT'`, which will
/// always come back empty.
enum AttendanceStatus {
  present('PRESENT'),
  absent('ABSENT');

  const AttendanceStatus(this.wireValue);

  /// How the status is stored in `attendance_records.status`.
  final String wireValue;

  /// Reads a stored value, defaulting to [absent] for anything unrecognised so
  /// a future status cannot make a student silently count as present.
  static AttendanceStatus fromWireValue(String value) {
    return AttendanceStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

/// Lifecycle of an attendance session.
///
/// Stored in `attendance_sessions.status`. Lower case because that is what
/// earlier versions of the app already wrote there.
enum AttendanceSessionStatus {
  open('open'),
  completed('completed');

  const AttendanceSessionStatus(this.wireValue);

  final String wireValue;

  /// True while the session still accepts scans.
  bool get isOpen => this == AttendanceSessionStatus.open;

  static AttendanceSessionStatus fromWireValue(String value) {
    return AttendanceSessionStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => AttendanceSessionStatus.open,
    );
  }
}

/// The shift/trip an attendance session was taken for.
enum TripType {
  morning('morning', 'Morning'),
  evening('evening', 'Evening');

  const TripType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static TripType fromWireValue(String value) {
    return TripType.values.firstWhere(
      (t) => t.wireValue == value,
      orElse: () => TripType.morning,
    );
  }
}

/// What happened when a barcode was presented during a session.
///
/// Each outcome carries the exact wording shown to the operator. [ambiguous]
/// shares [notFound]'s wording on purpose: a barcode containing several
/// registered roll numbers identifies nobody in particular, so it must not mark
/// anyone, and inventing a fourth message for it would only suggest the app
/// could act on it.
enum AttendanceScanOutcome {
  marked('Attendance Marked'),
  alreadyPresent('Already Present'),
  notFound('Student Not Found'),
  ambiguous('Student Not Found');

  const AttendanceScanOutcome(this.label);

  /// The message shown to the operator.
  final String label;

  /// Whether this outcome left a new row in `attendance_records`.
  bool get didMark => this == AttendanceScanOutcome.marked;
}

/// One student as they stand in the current session.
class StudentAttendance {
  const StudentAttendance({
    required this.student,
    required this.status,
    this.record,
  });

  /// A student who has not been marked, and therefore has no record.
  const StudentAttendance.absent(Student student)
    : this(student: student, status: AttendanceStatus.absent);

  final Student student;

  final AttendanceStatus status;

  /// The record backing a PRESENT status. Null when ABSENT, because absent
  /// students have no row.
  final AttendanceRecord? record;

  bool get isPresent => status == AttendanceStatus.present;

  /// When the student was marked, or null if they never were.
  ///
  /// Held on the record rather than recomputed so that re-scanning a card shows
  /// the time of the *first* scan, which is when the student actually arrived.
  DateTime? get scannedAt => record?.scannedAt;

  @override
  String toString() =>
      'StudentAttendance(${student.rollNo}, ${status.wireValue})';
}

/// The outcome of asking the database to mark a student present.
///
/// [isNew] distinguishes a first scan from a repeat. Both return the record
/// that exists afterwards, which for a repeat is the *original* one, keeping the
/// student's true arrival time intact.
class MarkPresentResult {
  const MarkPresentResult({required this.record, required this.isNew});

  final AttendanceRecord record;

  /// True when this call created the row, false when one already existed.
  final bool isNew;
}

/// Summary of an attendance session for the history list.
class AttendanceSessionSummary {
  const AttendanceSessionSummary({
    required this.sessionId,
    required this.attendanceDate,
    this.tripType = 'morning',
    required this.status,
    required this.total,
    required this.present,
    required this.absent,
    required this.percent,
    this.startedAt,
    this.endedAt,
  });

  final int sessionId;
  final DateTime attendanceDate;
  final String tripType;
  final AttendanceSessionStatus status;
  final int total;
  final int present;
  final int absent;
  final double percent;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

/// A single roster entry in session details (uses snapshot fields).
class AttendanceHistoryEntry {
  const AttendanceHistoryEntry({
    required this.sessionId,
    required this.studentId,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
    required this.status,
    this.scannedAt,
  });

  final int sessionId;
  final int studentId;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
  final AttendanceStatus status;
  final DateTime? scannedAt;
}

/// Filters for session details.
class AttendanceHistoryFilters {
  const AttendanceHistoryFilters({
    this.query = '',
    this.status = AttendanceFilter.all,
    this.institution,
    this.boardingPoint,
  });

  final String query;
  final AttendanceFilter status;
  final String? institution;
  final String? boardingPoint;
}

/// A session's summary together with its frozen roster entries.
class AttendanceSessionDetails {
  const AttendanceSessionDetails({
    required this.summary,
    required this.entries,
  });

  final AttendanceSessionSummary summary;
  final List<AttendanceHistoryEntry> entries;

  List<String> get institutions => _distinct((e) => e.institution);

  List<String> get boardingPoints => _distinct((e) => e.boardingPoint);

  List<String> _distinct(String Function(AttendanceHistoryEntry) select) {
    final seen = <String>{};
    for (final entry in entries) {
      seen.add(select(entry));
    }
    final values = seen.toList()..sort();
    return values;
  }

  /// Applies the query and dropdown filters, keeping the roster order.
  ///
  /// Search matches roll number and name only, mirroring Take Attendance.
  List<AttendanceHistoryEntry> filtered(AttendanceHistoryFilters filters) {
    final query = filters.query.trim().toLowerCase();
    return [
      for (final entry in entries)
        if (_matchesStatus(entry, filters.status) &&
            _matchesDropdown(entry.institution, filters.institution) &&
            _matchesDropdown(entry.boardingPoint, filters.boardingPoint) &&
            (query.isEmpty ||
                '${entry.rollNo} ${entry.name}'.toLowerCase().contains(query)))
          entry,
    ];
  }

  static bool _matchesStatus(
    AttendanceHistoryEntry entry,
    AttendanceFilter filter,
  ) {
    return switch (filter) {
      AttendanceFilter.present => entry.status == AttendanceStatus.present,
      AttendanceFilter.absent => entry.status == AttendanceStatus.absent,
      AttendanceFilter.all => true,
    };
  }

  static bool _matchesDropdown(String value, String? selected) {
    if (selected == null || selected.isEmpty) return true;
    return value == selected;
  }
}

enum AttendanceFilter { present, absent, all }
