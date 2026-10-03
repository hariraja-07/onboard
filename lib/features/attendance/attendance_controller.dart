import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/attendance_record_repository.dart';
import '../../core/database/repositories/attendance_session_repository.dart';
import '../../core/database/repositories/attendance_session_roster_repository.dart';
import '../../core/database/repositories/student_repository.dart';
import 'barcode/barcode_service.dart';
import 'models/attendance_models.dart';

/// Where the operator is in the session lifecycle.
enum AttendancePhase {
  /// Nothing has been read yet.
  idle,

  /// Looking for today's session and the roster.
  loading,

  /// Waiting for the operator to start a new session or resume an open one.
  awaitingStart,

  /// A session is open and scans are being accepted.
  active,

  /// The session has been completed and no longer accepts scans.
  finished,
}

final attendanceControllerProvider =
    StateNotifierProvider.autoDispose<AttendanceController, AttendanceState>((
      ref,
    ) {
      return AttendanceController(
        studentRepository: ref.watch(studentRepositoryProvider),
        sessionRepository: ref.watch(attendanceSessionRepositoryProvider),
        recordRepository: ref.watch(attendanceRecordRepositoryProvider),
        rosterRepository: ref.watch(attendanceSessionRosterRepositoryProvider),
        service: const BarcodeService(),
      );
    });

/// Everything the Take Attendance screen renders.
class AttendanceState {
  const AttendanceState({
    this.phase = AttendancePhase.idle,
    this.attendanceDate,
    this.sessionId,
    this.resumableSessionId,
    this.roster = const [],
    this.lastOutcome,
    this.lastBarcode,
    this.lastRecord,
    this.lastStudent,
    this.error,
    this.isMarking = false,
  });

  final AttendancePhase phase;

  /// The day being marked, once known.
  final DateTime? attendanceDate;

  /// The open session, while [phase] is [AttendancePhase.active].
  final int? sessionId;

  /// An open session that was found but not yet taken up.
  final int? resumableSessionId;

  /// Every registered student, with their derived status for this session.
  final List<StudentAttendance> roster;

  final AttendanceScanOutcome? lastOutcome;

  /// The scanned value, exactly as received.
  final String? lastBarcode;

  /// The record behind the last scan, for a matched or duplicate student.
  final AttendanceRecord? lastRecord;

  final Student? lastStudent;

  final String? error;

  /// True while a mark is being written, so the UI can avoid a second submit.
  final bool isMarking;

  /// True when a scan would do something.
  bool get isActive => phase == AttendancePhase.active;

  /// True when an open session exists that could be picked back up.
  bool get canResume => resumableSessionId != null;

  /// True when there is no session to resume, so starting is the only option.
  bool get needsNewSession =>
      phase == AttendancePhase.awaitingStart && !canResume;

  int get totalCount => roster.length;

  int get presentCount => roster.where((entry) => entry.isPresent).length;

  int get absentCount => totalCount - presentCount;

  List<StudentAttendance> get presentStudents =>
      roster.where((entry) => entry.isPresent).toList();

  List<StudentAttendance> get absentStudents =>
      roster.where((entry) => !entry.isPresent).toList();

  /// Share of the roster marked present, to one decimal place.
  ///
  /// Guards the empty roster: 0/0 must read 0.0% rather than NaN.
  double get attendancePercent {
    if (totalCount == 0) return 0;
    return (presentCount / totalCount) * 100;
  }

  /// Sentinel separating "not supplied" from "supplied as null".
  ///
  /// A plain nullable parameter combined with `?? this.x` cannot express
  /// clearing a field, which is needed here every time a new scan replaces the
  /// previous result. See the same fix in `StudentsState.copyWith`.
  static const Object _unset = Object();

  AttendanceState copyWith({
    AttendancePhase? phase,
    Object? attendanceDate = _unset,
    Object? sessionId = _unset,
    Object? resumableSessionId = _unset,
    List<StudentAttendance>? roster,
    Object? lastOutcome = _unset,
    Object? lastBarcode = _unset,
    Object? lastRecord = _unset,
    Object? lastStudent = _unset,
    Object? error = _unset,
    bool? isMarking,
  }) {
    return AttendanceState(
      phase: phase ?? this.phase,
      attendanceDate: identical(attendanceDate, _unset)
          ? this.attendanceDate
          : attendanceDate as DateTime?,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as int?,
      resumableSessionId: identical(resumableSessionId, _unset)
          ? this.resumableSessionId
          : resumableSessionId as int?,
      roster: roster ?? this.roster,
      lastOutcome: identical(lastOutcome, _unset)
          ? this.lastOutcome
          : lastOutcome as AttendanceScanOutcome?,
      lastBarcode: identical(lastBarcode, _unset)
          ? this.lastBarcode
          : lastBarcode as String?,
      lastRecord: identical(lastRecord, _unset)
          ? this.lastRecord
          : lastRecord as AttendanceRecord?,
      lastStudent: identical(lastStudent, _unset)
          ? this.lastStudent
          : lastStudent as Student?,
      error: identical(error, _unset) ? this.error : error as String?,
      isMarking: isMarking ?? this.isMarking,
    );
  }

  @override
  String toString() =>
      'AttendanceState(${phase.name}, $presentCount/$totalCount present)';
}

/// Drives one attendance session.
///
/// Scans are written to SQLite as they happen and state is only published once
/// the write has returned, so what the screen shows is always already on disk.
/// That is what lets a session survive navigating away or the app being killed.
class AttendanceController extends StateNotifier<AttendanceState> {
  AttendanceController({
    required StudentRepository studentRepository,
    required AttendanceSessionRepository sessionRepository,
    required AttendanceRecordRepository recordRepository,
    AttendanceSessionRosterRepository? rosterRepository,
    required BarcodeService service,
    DateTime Function()? clock,
    Duration scanCooldown = defaultScanCooldown,
  }) : _students = studentRepository,
       _sessions = sessionRepository,
       _records = recordRepository,
       _roster = rosterRepository,
       _service = service,
       _clock = clock ?? DateTime.now,
       _scanCooldown = scanCooldown,
       super(const AttendanceState());

  /// How long an unchanged barcode is ignored after a camera scan. A card held
  /// in front of the lens is reported on every frame.
  static const Duration defaultScanCooldown = Duration(seconds: 2);

  final StudentRepository _students;
  final AttendanceSessionRepository _sessions;
  final AttendanceRecordRepository _records;
  final AttendanceSessionRosterRepository? _roster;
  final BarcodeService _service;
  final Duration _scanCooldown;
  final DateTime Function() _clock;

  String? _lastScannedBarcode;
  DateTime? _lastScanAt;

  /// Finds today's open session and loads the roster.
  ///
  /// Leaves the controller at [AttendancePhase.awaitingStart] either way, so a
  /// session is only ever begun by the operator's explicit choice.
  Future<void> load({DateTime? forDate}) async {
    final date = forDate ?? _clock();
    state = state.copyWith(
      phase: AttendancePhase.loading,
      attendanceDate: date,
      error: null,
    );
    try {
      final open = await _sessions.findOpenForDate(date);
      final roster = await _buildRoster();
      state = state.copyWith(
        phase: AttendancePhase.awaitingStart,
        attendanceDate: date,
        resumableSessionId: open?.id,
        roster: roster,
      );
    } catch (error) {
      state = state.copyWith(
        phase: AttendancePhase.awaitingStart,
        error: 'Could not load attendance.\n$error',
      );
    }
  }

  /// Begins a new session for the loaded date.
  Future<void> startSession() async {
    final date = state.attendanceDate ?? _clock();
    state = state.copyWith(isMarking: true, error: null);
    try {
      final now = _clock();
      final id = await _sessions.createOpen(
        attendanceDate: date,
        createdAt: now,
      );
      _resetScanCooldown();
      // The session id has to be published before the roster is built: the
      // roster reads which records already exist, and it identifies the session
      // from state. Setting both in one copyWith would build the roster first,
      // against the previous session.
      state = state.copyWith(
        phase: AttendancePhase.active,
        attendanceDate: date,
        sessionId: id,
        // A newly started session supersedes any open one found earlier.
        resumableSessionId: null,
        isMarking: false,
      );
      await _captureRoster(id);
      state = state.copyWith(
        roster: await _buildRoster(),
        lastOutcome: null,
        lastBarcode: null,
        lastRecord: null,
        lastStudent: null,
      );
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        error: 'Could not start the session.\n$error',
      );
    }
  }

  /// Picks up the open session found by [load].
  Future<void> resumeSession() async {
    final id = state.resumableSessionId;
    if (id == null) {
      state = state.copyWith(error: 'There is no session to resume.');
      return;
    }
    state = state.copyWith(isMarking: true, error: null);
    try {
      _resetScanCooldown();
      // As in startSession: publish the id before building the roster, which
      // reads records for that session. Marks made before the interruption have
      // to come back as present.
      state = state.copyWith(
        phase: AttendancePhase.active,
        sessionId: id,
        isMarking: false,
      );
      await _captureRoster(id);
      state = state.copyWith(
        roster: await _buildRoster(),
        lastOutcome: null,
        lastBarcode: null,
        lastRecord: null,
        lastStudent: null,
      );
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        error: 'Could not resume the session.\n$error',
      );
    }
  }

  /// Completes the session. It will not accept further scans afterwards.
  Future<void> finishSession() async {
    final id = state.sessionId;
    if (id == null) return;
    try {
      await _sessions.complete(id);
      state = state.copyWith(
        phase: AttendancePhase.finished,
        sessionId: null,
        isMarking: false,
      );
    } catch (error) {
      state = state.copyWith(error: 'Could not finish the session.\n$error');
    }
  }

  /// Matches a barcode from the camera.
  ///
  /// An unchanged value is swallowed for [_scanCooldown], so a card resting in
  /// front of the lens does not rewrite the result several times a second.
  ///
  /// Returns the mark in progress so a caller can await the write.
  Future<void> onBarcodeScanned(String rawBarcode) async {
    final now = _clock();
    final previousAt = _lastScanAt;
    if (rawBarcode == _lastScannedBarcode &&
        previousAt != null &&
        now.difference(previousAt) < _scanCooldown) {
      return;
    }
    _lastScannedBarcode = rawBarcode;
    _lastScanAt = now;
    await scan(rawBarcode);
  }

  /// Matches a barcode typed in by hand. Never rate limited, so the same value
  /// can be retried.
  Future<void> submitBarcode(String rawBarcode) => scan(rawBarcode);

  /// The one path every scan takes, whatever its source.
  ///
  /// Scans before a session is open are ignored rather than silently dropped,
  /// since nothing could be recorded for them.
  Future<void> scan(String rawBarcode) async {
    final sessionId = state.sessionId;
    if (!state.isActive || sessionId == null || state.isMarking) return;

    state = state.copyWith(
      isMarking: true,
      lastBarcode: rawBarcode,
      error: null,
    );
    try {
      final match = _service.match(
        rawBarcode,
        state.roster.map((e) => e.student).toList(),
      );

      if (!match.isMatched || match.student == null) {
        // An ambiguous barcode names nobody in particular, so it must not mark
        // anyone; both cases share the "Student Not Found" wording.
        state = state.copyWith(
          lastOutcome: match.isAmbiguous
              ? AttendanceScanOutcome.ambiguous
              : AttendanceScanOutcome.notFound,
          lastRecord: null,
          lastStudent: match.isMatched ? match.student : null,
          isMarking: false,
        );
        return;
      }

      final student = match.student!;
      final result = await _records.markPresent(
        sessionId: sessionId,
        student: student,
        rawBarcode: rawBarcode,
        scannedAt: _clock(),
      );

      state = state.copyWith(
        lastOutcome: result.isNew
            ? AttendanceScanOutcome.marked
            : AttendanceScanOutcome.alreadyPresent,
        lastBarcode: rawBarcode,
        lastRecord: result.record,
        lastStudent: student,
        roster: _withStudentMarked(result.record),
        isMarking: false,
      );
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        error: 'Could not record the scan.\n$error',
      );
    }
  }

  /// Freezes the current student details against [sessionId].
  ///
  /// History must show the name, institution and boarding point as they were
  /// when attendance was taken, so later edits to a student cannot rewrite a
  /// past session. [AttendanceSessionRosterRepository.insertRoster] is
  /// idempotent, so resuming a session never overwrites an existing snapshot.
  Future<void> _captureRoster(int sessionId) async {
    final roster = _roster;
    if (roster == null) return;
    final students = await _students.getAll();
    await roster.insertRoster(sessionId, students);
  }

  /// Builds the roster, deriving PRESENT from the records already stored.
  Future<List<StudentAttendance>> _buildRoster() async {
    final sessionId = state.sessionId;
    final all = await _students.getAll();
    if (sessionId == null) {
      return all.map(StudentAttendance.absent).toList();
    }
    final presentIds = await _records.presentStudentIds(sessionId);
    if (presentIds.isEmpty) {
      return all.map(StudentAttendance.absent).toList();
    }
    final records = await _records.forSession(sessionId);
    final byStudent = {for (final record in records) record.studentId: record};
    return all
        .map(
          (student) => presentIds.contains(student.id)
              ? StudentAttendance(
                  student: student,
                  status: AttendanceStatus.present,
                  record: byStudent[student.id],
                )
              : StudentAttendance.absent(student),
        )
        .toList();
  }

  /// Returns a copy of the roster with one student flipped to present.
  ///
  /// Done in memory rather than by re-reading, so the UI updates immediately
  /// instead of waiting on another query.
  List<StudentAttendance> _withStudentMarked(AttendanceRecord record) {
    return [
      for (final entry in state.roster)
        if (entry.student.id == record.studentId)
          StudentAttendance(
            student: entry.student,
            status: AttendanceStatus.present,
            record: record,
          )
        else
          entry,
    ];
  }

  void _resetScanCooldown() {
    _lastScannedBarcode = null;
    _lastScanAt = null;
  }
}
