import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/constants.dart';
import 'backup_models.dart';
import '../../features/attendance/models/attendance_models.dart';

/// Reads and writes OnBoard backups: a small, self-describing JSON envelope.
///
/// This service is deliberately free of file-picking and filesystem concerns —
/// callers hand it bytes and get bytes or an in-memory [BackupData] back. That
/// keeps the format and, more importantly, the destructive [restore] path
/// unit-testable against an in-memory database.
class BackupService {
  BackupService(this.db);

  final AppDatabase db;

  /// Marker written into every backup so we can reject an unrelated JSON file.
  static const String format = 'onboard.backup';

  /// Bumped only when the envelope's shape changes incompatibly. Older files
  /// remain readable: [decodeAndValidate] accepts any version <= this one.
  static const int formatVersion = 1;

  /// Suggested filename extension, so backups sort and look distinct.
  static const String fileExtension = 'onboard';

  /// Guard against loading a huge/hostile file into memory as JSON. 50 MB is
  /// far beyond any plausible attendance database.
  static const int maxBackupBytes = 50 * 1024 * 1024;

  static const List<String> _autoIncrementTables = [
    'students',
    'attendance_sessions',
    'attendance_records',
    'attendance_session_roster',
  ];

  /// Captures the whole database as an in-memory backup.
  Future<BackupData> snapshot() async {
    final students = await db.select(db.students).get();
    final sessions = await db.select(db.attendanceSessions).get();
    final records = await db.select(db.attendanceRecords).get();
    final roster = await db.select(db.attendanceSessionRoster).get();

    return BackupData(
      formatVersion: formatVersion,
      appVersion: appVersion,
      schemaVersion: db.schemaVersion,
      exportedAt: DateTime.now(),
      students: students,
      sessions: sessions,
      records: records,
      roster: roster,
    );
  }

  /// Serializes [data] to the bytes written to a `.onboard` file.
  Uint8List encode(BackupData data) {
    final json = <String, Object?>{
      'format': format,
      'formatVersion': data.formatVersion,
      'appVersion': data.appVersion,
      'schemaVersion': data.schemaVersion,
      'exportedAt': data.exportedAt.millisecondsSinceEpoch,
      'settings': data.settings,
      'counts': {
        'students': data.studentCount,
        'attendanceSessions': data.sessionCount,
        'attendanceRecords': data.recordCount,
        'attendanceSessionRoster': data.rosterCount,
      },
      'data': {
        'students': data.students.map(_studentToJson).toList(),
        'attendanceSessions': data.sessions.map(_sessionToJson).toList(),
        'attendanceRecords': data.records.map(_recordToJson).toList(),
        'attendanceSessionRoster': data.roster.map(_rosterToJson).toList(),
      },
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
  }

  /// Parses and fully validates backup [bytes].
  ///
  /// Throws a [BackupException] with an operator-readable message for anything
  /// wrong: not JSON, not an OnBoard file, a newer format/schema, missing or
  /// mistyped fields, or duplicated keys that would break the restore. The
  /// returned [BackupData] is safe to hand straight to [restore].
  BackupData decodeAndValidate(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const BackupException('That backup file is empty.');
    }
    if (bytes.length > maxBackupBytes) {
      throw const BackupException(
        'That backup file is larger than OnBoard can read (over 50 MB).',
      );
    }

    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const BackupException(
        'That file is not an OnBoard backup (it is not readable text).',
      );
    }

    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const BackupException(
        'That file is not an OnBoard backup (it is not valid JSON).',
      );
    }
    if (root is! Map) {
      throw const BackupException('That is not an OnBoard backup file.');
    }
    final map = root.cast<String, Object?>();

    if (map['format'] != format) {
      throw const BackupException(
        'That is not an OnBoard backup file. Choose a file created by '
        '"Back up data".',
      );
    }

    final rootReader = _Reader('backup file');
    final fileFormatVersion = rootReader.integer(map, 'formatVersion');
    if (fileFormatVersion > formatVersion) {
      throw BackupException(
        'This backup was made by a newer version of OnBoard '
        '(format $fileFormatVersion). Update the app, then restore it.',
      );
    }
    final fileSchemaVersion = rootReader.integer(map, 'schemaVersion');
    if (fileSchemaVersion > db.schemaVersion) {
      throw BackupException(
        'This backup was made by a newer version of OnBoard '
        '(schema $fileSchemaVersion). Update the app, then restore it.',
      );
    }

    final exportedAt = rootReader.date(map, 'exportedAt');
    final fileAppVersion = map['appVersion'] is String
        ? map['appVersion']! as String
        : 'unknown';

    final settings = map['settings'];
    final settingsMap = settings is Map
        ? settings.cast<String, Object?>()
        : const <String, Object?>{};

    final data = rootReader.map(map, 'data');

    final students = _readList(
      data,
      'students',
      (entry, context) => _studentFromJson(entry, context),
    );
    final sessions = _readList(
      data,
      'attendanceSessions',
      (entry, context) => _sessionFromJson(entry, context),
    );
    final records = _readList(
      data,
      'attendanceRecords',
      (entry, context) => _recordFromJson(entry, context),
    );
    final roster = _readList(
      data,
      'attendanceSessionRoster',
      (entry, context) => _rosterFromJson(entry, context),
    );

    _checkUniqueIds(students.map((s) => s.id), 'students');
    _checkUniqueIds(sessions.map((s) => s.id), 'attendance sessions');
    _checkUniqueIds(records.map((r) => r.id), 'attendance records');
    _checkUniqueIds(roster.map((r) => r.id), 'roster entries');
    _checkUniquePairs(
      records.map((r) => '${r.sessionId}:${r.studentId}'),
      'attendance records',
    );
    _checkUniquePairs(
      roster.map((r) => '${r.sessionId}:${r.studentId}'),
      'roster entries',
    );

    _checkSupportedStatuses(sessions, records);
    _checkReferences(
      studentIds: students.map((s) => s.id).toSet(),
      sessionIds: sessions.map((s) => s.id).toSet(),
      records: records,
      roster: roster,
    );

    return BackupData(
      formatVersion: fileFormatVersion,
      appVersion: fileAppVersion,
      schemaVersion: fileSchemaVersion,
      exportedAt: exportedAt,
      settings: settingsMap,
      students: students,
      sessions: sessions,
      records: records,
      roster: roster,
    );
  }

  /// Replaces all current data with [data], in one transaction.
  ///
  /// Deletes run children-first and inserts parents-first so the result is
  /// correct even where foreign keys are (or later become) enforced. Ids are
  /// preserved so historical references keep pointing at the same rows.
  Future<void> restore(BackupData data) async {
    await db.transaction(() async {
      await db.delete(db.attendanceRecords).go();
      await db.delete(db.attendanceSessionRoster).go();
      await db.delete(db.attendanceSessions).go();
      await db.delete(db.students).go();

      await db.batch((batch) {
        batch.insertAll(
          db.students,
          data.students.map(
            (s) => StudentsCompanion(
              id: Value(s.id),
              rollNo: Value(s.rollNo),
              name: Value(s.name),
              institution: Value(s.institution),
              boardingPoint: Value(s.boardingPoint),
              createdAt: Value(s.createdAt),
              updatedAt: Value(s.updatedAt),
            ),
          ),
        );
        batch.insertAll(
          db.attendanceSessions,
          data.sessions.map(
            (s) => AttendanceSessionsCompanion(
              id: Value(s.id),
              attendanceDate: Value(s.attendanceDate),
              status: Value(s.status),
              createdAt: Value(s.createdAt),
              endedAt: Value(s.endedAt),
            ),
          ),
        );
        batch.insertAll(
          db.attendanceRecords,
          data.records.map(
            (r) => AttendanceRecordsCompanion(
              id: Value(r.id),
              sessionId: Value(r.sessionId),
              studentId: Value(r.studentId),
              rollNoSnapshot: Value(r.rollNoSnapshot),
              nameSnapshot: Value(r.nameSnapshot),
              institutionSnapshot: Value(r.institutionSnapshot),
              boardingPointSnapshot: Value(r.boardingPointSnapshot),
              status: Value(r.status),
              scannedBarcode: Value(r.scannedBarcode),
              scannedAt: Value(r.scannedAt),
            ),
          ),
        );
        batch.insertAll(
          db.attendanceSessionRoster,
          data.roster.map(
            (r) => AttendanceSessionRosterCompanion(
              id: Value(r.id),
              sessionId: Value(r.sessionId),
              studentId: Value(r.studentId),
              rollNo: Value(r.rollNo),
              name: Value(r.name),
              institution: Value(r.institution),
              boardingPoint: Value(r.boardingPoint),
              createdAt: Value(r.createdAt),
            ),
          ),
        );
      });

      await _resetSequences();
    });
  }

  /// Deletes every student, session, record and roster entry.
  ///
  /// Also resets the auto-increment counters so a cleared install numbers its
  /// next student from 1 rather than continuing from deleted rows.
  Future<void> clearAll() async {
    await db.transaction(() async {
      await db.delete(db.attendanceRecords).go();
      await db.delete(db.attendanceSessionRoster).go();
      await db.delete(db.attendanceSessions).go();
      await db.delete(db.students).go();
      for (final table in _autoIncrementTables) {
        await db.customStatement('DELETE FROM sqlite_sequence WHERE name = ?', [
          table,
        ]);
      }
    });
  }

  Future<void> _resetSequences() async {
    for (final table in _autoIncrementTables) {
      final row = await db
          .customSelect('SELECT COALESCE(MAX(id), 0) AS m FROM $table')
          .getSingle();
      final maxId = row.read<int>('m');
      await db.customStatement(
        'UPDATE sqlite_sequence SET seq = ? WHERE name = ?',
        [maxId, table],
      );
    }
  }

  List<T> _readList<T>(
    Map<String, Object?> data,
    String key,
    T Function(Map<String, Object?> entry, String context) parse,
  ) {
    final value = data[key];
    if (value is! List) {
      throw BackupException('The backup is missing its "$key" list.');
    }
    return [
      for (var i = 0; i < value.length; i++)
        parse(
          _asMap(value[i], 'The backup has a malformed "$key" entry.'),
          '$key[$i]',
        ),
    ];
  }

  Map<String, Object?> _asMap(Object? value, String message) {
    if (value is! Map) throw BackupException(message);
    return value.cast<String, Object?>();
  }

  void _checkUniqueIds(Iterable<int> ids, String what) {
    final seen = <int>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw BackupException(
          'The backup has two $what with the same id ($id), so it cannot be '
          'restored safely.',
        );
      }
    }
  }

  void _checkUniquePairs(Iterable<String> pairs, String what) {
    final seen = <String>{};
    for (final pair in pairs) {
      if (!seen.add(pair)) {
        throw BackupException(
          'The backup has duplicate $what for the same session and student, '
          'so it cannot be restored safely.',
        );
      }
    }
  }

  /// Rejects statuses the app does not understand, so a restored database can
  /// never contain rows the UI would render incorrectly.
  void _checkSupportedStatuses(
    List<AttendanceSession> sessions,
    List<AttendanceRecord> records,
  ) {
    final sessionStatuses = {
      AttendanceSessionStatus.open.wireValue,
      AttendanceSessionStatus.completed.wireValue,
    };
    final sessionTripTypes = {'morning', 'evening'};
    for (final session in sessions) {
      if (!sessionStatuses.contains(session.status)) {
        throw BackupException(
          'The backup has an attendance session with an unsupported status '
          '("${session.status}").',
        );
      }
      if (!sessionTripTypes.contains(session.tripType)) {
        throw BackupException(
          'The backup has an attendance session with an unsupported trip type '
          '("${session.tripType}").',
        );
      }
    }
    for (final record in records) {
      if (record.status != AttendanceStatus.present.wireValue) {
        throw BackupException(
          'The backup has an attendance record with an unsupported status '
          '("${record.status}").',
        );
      }
    }
  }

  /// Every record and roster entry must point at a student and a session that
  /// the same backup contains. Foreign keys are not enforced at runtime, so
  /// this is the only guard against a backup restoring dangling references.
  void _checkReferences({
    required Set<int> studentIds,
    required Set<int> sessionIds,
    required List<AttendanceRecord> records,
    required List<AttendanceSessionRosterData> roster,
  }) {
    for (final record in records) {
      if (!sessionIds.contains(record.sessionId)) {
        throw BackupException(
          'The backup has an attendance record for a session that is not in '
          'the file (session ${record.sessionId}).',
        );
      }
      if (!studentIds.contains(record.studentId)) {
        throw BackupException(
          'The backup has an attendance record for a student that is not in '
          'the file (student ${record.studentId}).',
        );
      }
    }
    for (final entry in roster) {
      if (!sessionIds.contains(entry.sessionId)) {
        throw BackupException(
          'The backup has a roster entry for a session that is not in the '
          'file (session ${entry.sessionId}).',
        );
      }
      if (!studentIds.contains(entry.studentId)) {
        throw BackupException(
          'The backup has a roster entry for a student that is not in the '
          'file (student ${entry.studentId}).',
        );
      }
    }
  }

  Map<String, Object?> _studentToJson(Student s) => {
    'id': s.id,
    'rollNo': s.rollNo,
    'name': s.name,
    'institution': s.institution,
    'boardingPoint': s.boardingPoint,
    'createdAt': s.createdAt.millisecondsSinceEpoch,
    'updatedAt': s.updatedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> _sessionToJson(AttendanceSession s) => {
    'id': s.id,
    'attendanceDate': s.attendanceDate.millisecondsSinceEpoch,
    'tripType': s.tripType,
    'status': s.status,
    'createdAt': s.createdAt.millisecondsSinceEpoch,
    'endedAt': s.endedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> _recordToJson(AttendanceRecord r) => {
    'id': r.id,
    'sessionId': r.sessionId,
    'studentId': r.studentId,
    'rollNoSnapshot': r.rollNoSnapshot,
    'nameSnapshot': r.nameSnapshot,
    'institutionSnapshot': r.institutionSnapshot,
    'boardingPointSnapshot': r.boardingPointSnapshot,
    'status': r.status,
    'scannedBarcode': r.scannedBarcode,
    'scannedAt': r.scannedAt.millisecondsSinceEpoch,
  };

  Map<String, Object?> _rosterToJson(AttendanceSessionRosterData r) => {
    'id': r.id,
    'sessionId': r.sessionId,
    'studentId': r.studentId,
    'rollNo': r.rollNo,
    'name': r.name,
    'institution': r.institution,
    'boardingPoint': r.boardingPoint,
    'createdAt': r.createdAt.millisecondsSinceEpoch,
  };

  Student _studentFromJson(Map<String, Object?> json, String context) {
    final r = _Reader(context);
    return Student(
      id: r.integer(json, 'id'),
      rollNo: r.string(json, 'rollNo'),
      name: r.string(json, 'name'),
      institution: r.string(json, 'institution'),
      boardingPoint: r.string(json, 'boardingPoint'),
      createdAt: r.date(json, 'createdAt'),
      updatedAt: r.optionalDate(json, 'updatedAt'),
    );
  }

  AttendanceSession _sessionFromJson(
    Map<String, Object?> json,
    String context,
  ) {
    final r = _Reader(context);
    return AttendanceSession(
      id: r.integer(json, 'id'),
      attendanceDate: r.date(json, 'attendanceDate'),
      tripType: json.containsKey('tripType')
          ? r.string(json, 'tripType')
          : 'morning',
      status: r.string(json, 'status'),
      createdAt: r.date(json, 'createdAt'),
      endedAt: r.optionalDate(json, 'endedAt'),
    );
  }

  AttendanceRecord _recordFromJson(Map<String, Object?> json, String context) {
    final r = _Reader(context);
    return AttendanceRecord(
      id: r.integer(json, 'id'),
      sessionId: r.integer(json, 'sessionId'),
      studentId: r.integer(json, 'studentId'),
      rollNoSnapshot: r.string(json, 'rollNoSnapshot'),
      nameSnapshot: r.string(json, 'nameSnapshot'),
      institutionSnapshot: r.string(json, 'institutionSnapshot'),
      boardingPointSnapshot: r.string(json, 'boardingPointSnapshot'),
      status: r.string(json, 'status'),
      scannedBarcode: r.string(json, 'scannedBarcode'),
      scannedAt: r.date(json, 'scannedAt'),
    );
  }

  AttendanceSessionRosterData _rosterFromJson(
    Map<String, Object?> json,
    String context,
  ) {
    final r = _Reader(context);
    return AttendanceSessionRosterData(
      id: r.integer(json, 'id'),
      sessionId: r.integer(json, 'sessionId'),
      studentId: r.integer(json, 'studentId'),
      rollNo: r.string(json, 'rollNo'),
      name: r.string(json, 'name'),
      institution: r.string(json, 'institution'),
      boardingPoint: r.string(json, 'boardingPoint'),
      createdAt: r.date(json, 'createdAt'),
    );
  }
}

/// Reads one field at a time, prefixing every failure with the row's path so a
/// problem in a large file points at the exact entry.
class _Reader {
  const _Reader(this.context);

  final String context;

  Never _fail(String message) => throw BackupException('$context $message');

  int integer(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    _fail('is missing a whole number for "$key".');
  }

  String string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    _fail('is missing text for "$key".');
  }

  DateTime date(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    _fail('is missing a date for "$key".');
  }

  DateTime? optionalDate(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    return date(json, key);
  }

  Map<String, Object?> map(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is Map) return value.cast<String, Object?>();
    _fail('is missing its "$key" section.');
  }
}
