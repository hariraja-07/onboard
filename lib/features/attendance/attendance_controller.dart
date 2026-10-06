import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/attendance_record_repository.dart';
import '../../core/database/repositories/attendance_session_repository.dart';
import '../../core/database/repositories/attendance_session_roster_repository.dart';
import '../../core/database/repositories/student_repository.dart';
import '../dashboard/dashboard_service.dart';
import '../history/history_controller.dart';
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

  /// A session is open but scanning is temporarily suspended.
  paused,

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
        onSessionChanged: () {
          ref.invalidate(dashboardProvider);
          ref.invalidate(attendanceHistoryProvider);
        },
      );
    });

/// Everything the Take Attendance screen renders.
class AttendanceState {
  const AttendanceState({
    this.phase = AttendancePhase.idle,
    this.attendanceDate,
    this.tripType = TripType.morning,
    this.sessionId,
    this.resumableSessionId,
    this.roster = const [],
    this.lastOutcome,
    this.lastBarcode,
    this.lastRecord,
    this.lastStudent,
    this.error,
    this.isMarking = false,
    this.isSessionBusy = false,
  });

  final AttendancePhase phase;

  /// The day being marked, once known.
  final DateTime? attendanceDate;

  /// The shift/trip being marked (morning or evening).
  final TripType tripType;

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

  /// True while a session is starting, resuming or finishing.
  ///
  /// Separate from [isMarking] because scans also set that flag briefly; the
  /// session buttons must stay enabled during a normal scan and only disable
  /// for the action they triggered.
  final bool isSessionBusy;

  /// True when a scan would do something.
  bool get isActive => phase == AttendancePhase.active;

  /// True when the session is still open but scanning is suspended.
  bool get isPaused => phase == AttendancePhase.paused;

  /// True while the session is open, whether or not it is currently scanning.
  bool get isSessionOpen =>
      phase == AttendancePhase.active || phase == AttendancePhase.paused;

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
    TripType? tripType,
    Object? sessionId = _unset,
    Object? resumableSessionId = _unset,
    List<StudentAttendance>? roster,
    Object? lastOutcome = _unset,
    Object? lastBarcode = _unset,
    Object? lastRecord = _unset,
    Object? lastStudent = _unset,
    Object? error = _unset,
    bool? isMarking,
    bool? isSessionBusy,
  }) {
    return AttendanceState(
      phase: phase ?? this.phase,
      attendanceDate: identical(attendanceDate, _unset)
          ? this.attendanceDate
          : attendanceDate as DateTime?,
      tripType: tripType ?? this.tripType,
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
      isSessionBusy: isSessionBusy ?? this.isSessionBusy,
    );
  }

  @override
  String toString() =>
      'AttendanceState(${phase.name}, ${tripType.label}, $presentCount/$totalCount present)';
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
    VoidCallback? onSessionChanged,
    DateTime Function()? clock,
    Duration scanCooldown = defaultScanCooldown,
  }) : _students = studentRepository,
       _sessions = sessionRepository,
       _records = recordRepository,
       _roster = rosterRepository,
       _service = service,
       _onSessionChanged = onSessionChanged,
       _clock = clock ?? DateTime.now,
       _scanCooldown = scanCooldown,
       super(const AttendanceState());

  /// How long an unchanged barcode is ignored after a camera scan. A card held
  /// in front of the lens is reported on every frame.
  /// Slightly reduced to improve re-presentation responsiveness while avoiding
  /// frame spam; still guarded by plugin-side deduplication.
  static const Duration defaultScanCooldown = Duration(milliseconds: 1200);

  final StudentRepository _students;
  final AttendanceSessionRepository _sessions;
  final AttendanceRecordRepository _records;
  final AttendanceSessionRosterRepository? _roster;
  final BarcodeService _service;
  final VoidCallback? _onSessionChanged;
  final Duration _scanCooldown;
  final DateTime Function() _clock;

  String? _lastScannedBarcode;
  DateTime? _lastScanAt;

  /// Serializes scans so a barcode presented while an earlier one is still
  /// being written waits its turn instead of being dropped.
  Future<void> _scanQueue = Future.value();

  /// Changes the trip type before the session starts.
  void selectTrip(TripType trip) {
    if (state.phase == AttendancePhase.active || state.isSessionBusy) return;
    state = state.copyWith(tripType: trip);
  }

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
      // Any open session counts, not just today's, so one left open across
      // midnight is surfaced instead of becoming permanently stuck.
      final open = await _sessions.findAnyOpen();
      final roster = await _buildRoster();

      TripType suggestedTrip = TripType.morning;
      if (open != null) {
        suggestedTrip = TripType.fromWireValue(open.tripType);
      } else {
        final existingToday = await _sessions.forDate(date);
        final hasCompletedMorning = existingToday.any(
          (s) =>
              s.tripType == TripType.morning.wireValue &&
              s.status == AttendanceSessionStatus.completed.wireValue,
        );
        if (hasCompletedMorning) {
          suggestedTrip = TripType.evening;
        }
      }

      state = state.copyWith(
        phase: AttendancePhase.awaitingStart,
        attendanceDate: open?.attendanceDate ?? date,
        tripType: suggestedTrip,
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
  Future<void> startSession({TripType? trip}) async {
    if (state.isMarking) return;
    final tripToUse = trip ?? state.tripType;
    final date = state.attendanceDate ?? _clock();
    state = state.copyWith(
      isMarking: true,
      isSessionBusy: true,
      tripType: tripToUse,
      error: null,
    );
    try {
      final now = _clock();
      final id = await _sessions.findOrCreateOpen(
        attendanceDate: date,
        tripType: tripToUse.wireValue,
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
        tripType: tripToUse,
        sessionId: id,
        // A newly started session supersedes any open one found earlier.
        resumableSessionId: null,
      );
      await _captureRoster(id);
      state = state.copyWith(
        roster: await _buildRoster(),
        isMarking: false,
        isSessionBusy: false,
        lastOutcome: null,
        lastBarcode: null,
        lastRecord: null,
        lastStudent: null,
      );
      _onSessionChanged?.call();
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        isSessionBusy: false,
        error: 'Could not start the session.\n$error',
      );
    }
  }

  /// Picks up the open session found by [load].
  Future<void> resumeSession() async {
    if (state.isMarking) return;
    final id = state.resumableSessionId;
    if (id == null) {
      state = state.copyWith(error: 'There is no session to resume.');
      return;
    }
    state = state.copyWith(isMarking: true, isSessionBusy: true, error: null);
    try {
      _resetScanCooldown();
      final open = await _sessions.findAnyOpen();
      final trip = open != null
          ? TripType.fromWireValue(open.tripType)
          : state.tripType;
      // As in startSession: publish the id before building the roster, which
      // reads records for that session. Marks made before the interruption have
      // to come back as present.
      state = state.copyWith(
        phase: AttendancePhase.active,
        sessionId: id,
        tripType: trip,
      );
      await _captureRoster(id);
      state = state.copyWith(
        roster: await _buildRoster(),
        isMarking: false,
        isSessionBusy: false,
        lastOutcome: null,
        lastBarcode: null,
        lastRecord: null,
        lastStudent: null,
      );
      _onSessionChanged?.call();
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        isSessionBusy: false,
        error: 'Could not resume the session.\n$error',
      );
    }
  }

  /// Suspends scanning without ending the session.
  ///
  /// Nothing is written, and that is the point: the repository's complete is
  /// the only call that closes a session, so declining to call it leaves the
  /// session open and resumable. Synchronous for the same reason.
  ///
  /// The cooldown is reset so a card held while paused is not swallowed when
  /// scanning resumes, and the last outcome is cleared so the banner does not
  /// animate in again for a scan that predates the pause.
  void pauseSession() {
    if (state.phase != AttendancePhase.active || state.isMarking) return;
    _resetScanCooldown();
    state = state.copyWith(
      phase: AttendancePhase.paused,
      lastOutcome: null,
      lastBarcode: null,
      lastRecord: null,
      lastStudent: null,
    );
  }

  /// Resumes a paused session.
  ///
  /// The roster is already in state and the session row is still open, so there
  /// is nothing to reload and nothing to write.
  void resumeFromPause() {
    if (state.phase != AttendancePhase.paused || state.isMarking) return;
    _resetScanCooldown();
    state = state.copyWith(phase: AttendancePhase.active);
  }

  /// Completes the session. It will not accept further scans afterwards.
  Future<void> finishSession() async {
    if (state.isMarking) return;
    final id = state.sessionId;
    if (id == null) return;
    state = state.copyWith(isMarking: true, isSessionBusy: true, error: null);
    try {
      // Capture again so students added while the session was open join the
      // frozen roster. insertRoster is insert-or-ignore, so rows already
      // snapshotted keep their original values and history stays immutable.
      await _captureRoster(id);
      await _sessions.complete(id);
      final nextTrip = state.tripType == TripType.morning
          ? TripType.evening
          : TripType.morning;
      state = state.copyWith(
        phase: AttendancePhase.finished,
        sessionId: null,
        tripType: nextTrip,
        isMarking: false,
        isSessionBusy: false,
      );
      _onSessionChanged?.call();
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        isSessionBusy: false,
        error: 'Could not finish the session.\n$error',
      );
    }
  }

  /// Discards the currently active session if no attendance records have been scanned.
  ///
  /// Prevents accidental starts from cluttering history with empty abandoned sessions.
  Future<void> discardSession() async {
    final id = state.sessionId;
    if (id == null ||
        state.presentCount > 0 ||
        state.isMarking ||
        state.isSessionBusy) {
      return;
    }
    state = state.copyWith(isSessionBusy: true, error: null);
    try {
      await _sessions.deleteSession(id);
      _resetScanCooldown();
      state = state.copyWith(
        phase: AttendancePhase.awaitingStart,
        sessionId: null,
        resumableSessionId: null,
        isSessionBusy: false,
        lastOutcome: null,
        lastBarcode: null,
        lastRecord: null,
        lastStudent: null,
      );
      state = state.copyWith(roster: await _buildRoster());
      _onSessionChanged?.call();
    } catch (error) {
      state = state.copyWith(
        isSessionBusy: false,
        error: 'Could not discard the session.\n$error',
      );
    }
  }

  /// Matches a barcode from the camera.
  ///
  /// An unchanged value is swallowed for [_scanCooldown], so a card resting in
  /// front of the lens does not rewrite the result several times a second.
  ///
  /// Returns the mark in progress so a caller can await the write.
  Future<void> onBarcodeScanned(String rawBarcode) {
    final now = _clock();
    final previousAt = _lastScanAt;
    if (rawBarcode == _lastScannedBarcode &&
        previousAt != null &&
        now.difference(previousAt) < _scanCooldown) {
      return Future.value();
    }
    _lastScannedBarcode = rawBarcode;
    _lastScanAt = now;
    return _enqueueScan(rawBarcode);
  }

  /// Matches a barcode typed in by hand. Never rate limited, so the same value
  /// can be retried.
  Future<void> submitBarcode(String rawBarcode) => _enqueueScan(rawBarcode);

  /// Runs scans one after another. A scan arriving while another is being
  /// written is queued instead of dropped, so two cards presented in quick
  /// succession are both recorded.
  Future<void> _enqueueScan(String rawBarcode) {
    final next = _scanQueue.then((_) => scan(rawBarcode));
    _scanQueue = next;
    return next;
  }

  /// The one path every scan takes, whatever its source.
  ///
  /// Scans before a session is open are ignored rather than silently dropped,
  /// since nothing could be recorded for them.
  Future<void> scan(String rawBarcode) async {
    final sessionId = state.sessionId;
    if (!state.isActive || sessionId == null) return;
    if (state.isMarking) {
      // Don't drop silently during lifecycle writes; re-queue this scan
      // after the current work completes to avoid missing a boarding.
      unawaited(_enqueueScan(rawBarcode));
      return;
    }

    state = state.copyWith(
      isMarking: true,
      lastBarcode: rawBarcode,
      // Cleared rather than left in place: the previous outcome belongs to a
      // different barcode, and anything watching this state, including the
      // haptic listener on the page, would otherwise act on it as though it
      // were this scan's result.
      lastOutcome: null,
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
      if (result.isNew) {
        _onSessionChanged?.call();
      }
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        error: 'Could not record the scan.\n$error',
      );
    }
  }

  /// Undoes a present mark, putting the student back to absent.
  ///
  /// Runs on the same queue as [scan] so it cannot interleave with a scan that
  /// is mid-write: `scan` ignores calls while [AttendanceState.isMarking] is
  /// set, so an undo that set that flag itself would make a scan already
  /// queued behind it disappear without an error.
  Future<void> undoPresent(StudentAttendance entry) {
    final next = _scanQueue.then((_) => _undoPresent(entry));
    _scanQueue = next;
    return next;
  }

  Future<void> _undoPresent(StudentAttendance entry) async {
    final sessionId = state.sessionId;
    if (!state.isActive || sessionId == null) return;
    if (!entry.isPresent) return;

    state = state.copyWith(
      isMarking: true,
      error: null,
      // Cleared rather than left in place: an undo has no scan outcome, and the
      // banner and haptic listener on the page both key off this pair, so a
      // leftover value would be announced as though this were a scan.
      lastOutcome: null,
      lastBarcode: null,
      lastRecord: null,
      lastStudent: null,
    );
    try {
      final removed = await _records.deleteForStudent(
        sessionId,
        entry.student.id,
      );
      if (!removed) {
        state = state.copyWith(
          isMarking: false,
          error: 'Could not undo that mark. Try again.',
        );
        return;
      }
      state = state.copyWith(
        roster: _withStudentCleared(entry.student.id),
        isMarking: false,
      );
      _onSessionChanged?.call();
    } catch (error) {
      state = state.copyWith(
        isMarking: false,
        error: 'Could not undo the mark.\n$error',
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
  ///
  /// Prefers the frozen snapshot taken when the session opened so that mid-session
  /// edits to the student directory do not leak into the active attendance sheet.
  Future<List<StudentAttendance>> _buildRoster() async {
    final sessionId = state.sessionId;
    List<Student> all;
    final roster = _roster;
    if (sessionId != null && roster != null) {
      final frozen = await roster.getRoster(sessionId);
      if (frozen.isNotEmpty) {
        all = frozen
            .map(
              (r) => Student(
                id: r.studentId,
                rollNo: r.rollNo,
                name: r.name,
                institution: r.institution,
                boardingPoint: r.boardingPoint,
                createdAt: r.createdAt,
              ),
            )
            .toList();
      } else {
        all = await _students.getAll();
      }
    } else {
      all = await _students.getAll();
    }
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

  /// Puts [studentId] back to absent in the in-memory roster.
  ///
  /// Absence is derived rather than stored, so this drops the record and
  /// leaves the student on the roster, which is the same state a roster entry
  /// has before they are ever scanned.
  List<StudentAttendance> _withStudentCleared(int studentId) {
    return [
      for (final entry in state.roster)
        if (entry.student.id == studentId)
          StudentAttendance.absent(entry.student)
        else
          entry,
    ];
  }

  void _resetScanCooldown() {
    _lastScannedBarcode = null;
    _lastScanAt = null;
  }
}
