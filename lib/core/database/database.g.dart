// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StudentsTable extends Students with TableInfo<$StudentsTable, Student> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rollNoMeta = const VerificationMeta('rollNo');
  @override
  late final GeneratedColumn<String> rollNo = GeneratedColumn<String>(
    'roll_no',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardingPointMeta = const VerificationMeta(
    'boardingPoint',
  );
  @override
  late final GeneratedColumn<String> boardingPoint = GeneratedColumn<String>(
    'boarding_point',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rollNo,
    name,
    institution,
    boardingPoint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(
    Insertable<Student> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('roll_no')) {
      context.handle(
        _rollNoMeta,
        rollNo.isAcceptableOrUnknown(data['roll_no']!, _rollNoMeta),
      );
    } else if (isInserting) {
      context.missing(_rollNoMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionMeta);
    }
    if (data.containsKey('boarding_point')) {
      context.handle(
        _boardingPointMeta,
        boardingPoint.isAcceptableOrUnknown(
          data['boarding_point']!,
          _boardingPointMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boardingPointMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Student map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Student(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rollNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roll_no'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      )!,
      boardingPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}boarding_point'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $StudentsTable createAlias(String alias) {
    return $StudentsTable(attachedDatabase, alias);
  }
}

class Student extends DataClass implements Insertable<Student> {
  final int id;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Student({
    required this.id,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['roll_no'] = Variable<String>(rollNo);
    map['name'] = Variable<String>(name);
    map['institution'] = Variable<String>(institution);
    map['boarding_point'] = Variable<String>(boardingPoint);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  StudentsCompanion toCompanion(bool nullToAbsent) {
    return StudentsCompanion(
      id: Value(id),
      rollNo: Value(rollNo),
      name: Value(name),
      institution: Value(institution),
      boardingPoint: Value(boardingPoint),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Student.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Student(
      id: serializer.fromJson<int>(json['id']),
      rollNo: serializer.fromJson<String>(json['rollNo']),
      name: serializer.fromJson<String>(json['name']),
      institution: serializer.fromJson<String>(json['institution']),
      boardingPoint: serializer.fromJson<String>(json['boardingPoint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rollNo': serializer.toJson<String>(rollNo),
      'name': serializer.toJson<String>(name),
      'institution': serializer.toJson<String>(institution),
      'boardingPoint': serializer.toJson<String>(boardingPoint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Student copyWith({
    int? id,
    String? rollNo,
    String? name,
    String? institution,
    String? boardingPoint,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Student(
    id: id ?? this.id,
    rollNo: rollNo ?? this.rollNo,
    name: name ?? this.name,
    institution: institution ?? this.institution,
    boardingPoint: boardingPoint ?? this.boardingPoint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Student copyWithCompanion(StudentsCompanion data) {
    return Student(
      id: data.id.present ? data.id.value : this.id,
      rollNo: data.rollNo.present ? data.rollNo.value : this.rollNo,
      name: data.name.present ? data.name.value : this.name,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      boardingPoint: data.boardingPoint.present
          ? data.boardingPoint.value
          : this.boardingPoint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Student(')
          ..write('id: $id, ')
          ..write('rollNo: $rollNo, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('boardingPoint: $boardingPoint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rollNo,
    name,
    institution,
    boardingPoint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Student &&
          other.id == this.id &&
          other.rollNo == this.rollNo &&
          other.name == this.name &&
          other.institution == this.institution &&
          other.boardingPoint == this.boardingPoint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StudentsCompanion extends UpdateCompanion<Student> {
  final Value<int> id;
  final Value<String> rollNo;
  final Value<String> name;
  final Value<String> institution;
  final Value<String> boardingPoint;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const StudentsCompanion({
    this.id = const Value.absent(),
    this.rollNo = const Value.absent(),
    this.name = const Value.absent(),
    this.institution = const Value.absent(),
    this.boardingPoint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StudentsCompanion.insert({
    this.id = const Value.absent(),
    required String rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
  }) : rollNo = Value(rollNo),
       name = Value(name),
       institution = Value(institution),
       boardingPoint = Value(boardingPoint),
       createdAt = Value(createdAt);
  static Insertable<Student> custom({
    Expression<int>? id,
    Expression<String>? rollNo,
    Expression<String>? name,
    Expression<String>? institution,
    Expression<String>? boardingPoint,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rollNo != null) 'roll_no': rollNo,
      if (name != null) 'name': name,
      if (institution != null) 'institution': institution,
      if (boardingPoint != null) 'boarding_point': boardingPoint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StudentsCompanion copyWith({
    Value<int>? id,
    Value<String>? rollNo,
    Value<String>? name,
    Value<String>? institution,
    Value<String>? boardingPoint,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
  }) {
    return StudentsCompanion(
      id: id ?? this.id,
      rollNo: rollNo ?? this.rollNo,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      boardingPoint: boardingPoint ?? this.boardingPoint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rollNo.present) {
      map['roll_no'] = Variable<String>(rollNo.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (boardingPoint.present) {
      map['boarding_point'] = Variable<String>(boardingPoint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsCompanion(')
          ..write('id: $id, ')
          ..write('rollNo: $rollNo, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('boardingPoint: $boardingPoint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AttendanceSessionsTable extends AttendanceSessions
    with TableInfo<$AttendanceSessionsTable, AttendanceSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _attendanceDateMeta = const VerificationMeta(
    'attendanceDate',
  );
  @override
  late final GeneratedColumn<DateTime> attendanceDate =
      GeneratedColumn<DateTime>(
        'attendance_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripTypeMeta = const VerificationMeta(
    'tripType',
  );
  @override
  late final GeneratedColumn<String> tripType = GeneratedColumn<String>(
    'trip_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('morning'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    attendanceDate,
    status,
    createdAt,
    endedAt,
    tripType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('attendance_date')) {
      context.handle(
        _attendanceDateMeta,
        attendanceDate.isAcceptableOrUnknown(
          data['attendance_date']!,
          _attendanceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('trip_type')) {
      context.handle(
        _tripTypeMeta,
        tripType.isAcceptableOrUnknown(data['trip_type']!, _tripTypeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      attendanceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}attendance_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      tripType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_type'],
      )!,
    );
  }

  @override
  $AttendanceSessionsTable createAlias(String alias) {
    return $AttendanceSessionsTable(attachedDatabase, alias);
  }
}

class AttendanceSession extends DataClass
    implements Insertable<AttendanceSession> {
  final int id;
  final DateTime attendanceDate;
  final String status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String tripType;
  const AttendanceSession({
    required this.id,
    required this.attendanceDate,
    required this.status,
    required this.createdAt,
    this.endedAt,
    required this.tripType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['attendance_date'] = Variable<DateTime>(attendanceDate);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['trip_type'] = Variable<String>(tripType);
    return map;
  }

  AttendanceSessionsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceSessionsCompanion(
      id: Value(id),
      attendanceDate: Value(attendanceDate),
      status: Value(status),
      createdAt: Value(createdAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      tripType: Value(tripType),
    );
  }

  factory AttendanceSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceSession(
      id: serializer.fromJson<int>(json['id']),
      attendanceDate: serializer.fromJson<DateTime>(json['attendanceDate']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      tripType: serializer.fromJson<String>(json['tripType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'attendanceDate': serializer.toJson<DateTime>(attendanceDate),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'tripType': serializer.toJson<String>(tripType),
    };
  }

  AttendanceSession copyWith({
    int? id,
    DateTime? attendanceDate,
    String? status,
    DateTime? createdAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? tripType,
  }) => AttendanceSession(
    id: id ?? this.id,
    attendanceDate: attendanceDate ?? this.attendanceDate,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    tripType: tripType ?? this.tripType,
  );
  AttendanceSession copyWithCompanion(AttendanceSessionsCompanion data) {
    return AttendanceSession(
      id: data.id.present ? data.id.value : this.id,
      attendanceDate: data.attendanceDate.present
          ? data.attendanceDate.value
          : this.attendanceDate,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      tripType: data.tripType.present ? data.tripType.value : this.tripType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSession(')
          ..write('id: $id, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('tripType: $tripType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, attendanceDate, status, createdAt, endedAt, tripType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceSession &&
          other.id == this.id &&
          other.attendanceDate == this.attendanceDate &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.endedAt == this.endedAt &&
          other.tripType == this.tripType);
}

class AttendanceSessionsCompanion extends UpdateCompanion<AttendanceSession> {
  final Value<int> id;
  final Value<DateTime> attendanceDate;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<String> tripType;
  const AttendanceSessionsCompanion({
    this.id = const Value.absent(),
    this.attendanceDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.tripType = const Value.absent(),
  });
  AttendanceSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime attendanceDate,
    required String status,
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.tripType = const Value.absent(),
  }) : attendanceDate = Value(attendanceDate),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<AttendanceSession> custom({
    Expression<int>? id,
    Expression<DateTime>? attendanceDate,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endedAt,
    Expression<String>? tripType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attendanceDate != null) 'attendance_date': attendanceDate,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (tripType != null) 'trip_type': tripType,
    });
  }

  AttendanceSessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? attendanceDate,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endedAt,
    Value<String>? tripType,
  }) {
    return AttendanceSessionsCompanion(
      id: id ?? this.id,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      tripType: tripType ?? this.tripType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (attendanceDate.present) {
      map['attendance_date'] = Variable<DateTime>(attendanceDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (tripType.present) {
      map['trip_type'] = Variable<String>(tripType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSessionsCompanion(')
          ..write('id: $id, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('tripType: $tripType')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTable extends AttendanceRecords
    with TableInfo<$AttendanceRecordsTable, AttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendance_sessions (id)',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<int> studentId = GeneratedColumn<int>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _rollNoSnapshotMeta = const VerificationMeta(
    'rollNoSnapshot',
  );
  @override
  late final GeneratedColumn<String> rollNoSnapshot = GeneratedColumn<String>(
    'roll_no_snapshot',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameSnapshotMeta = const VerificationMeta(
    'nameSnapshot',
  );
  @override
  late final GeneratedColumn<String> nameSnapshot = GeneratedColumn<String>(
    'name_snapshot',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionSnapshotMeta =
      const VerificationMeta('institutionSnapshot');
  @override
  late final GeneratedColumn<String> institutionSnapshot =
      GeneratedColumn<String>(
        'institution_snapshot',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 150,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _boardingPointSnapshotMeta =
      const VerificationMeta('boardingPointSnapshot');
  @override
  late final GeneratedColumn<String> boardingPointSnapshot =
      GeneratedColumn<String>(
        'boarding_point_snapshot',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 150,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedBarcodeMeta = const VerificationMeta(
    'scannedBarcode',
  );
  @override
  late final GeneratedColumn<String> scannedBarcode = GeneratedColumn<String>(
    'scanned_barcode',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    studentId,
    rollNoSnapshot,
    nameSnapshot,
    institutionSnapshot,
    boardingPointSnapshot,
    status,
    scannedBarcode,
    scannedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('roll_no_snapshot')) {
      context.handle(
        _rollNoSnapshotMeta,
        rollNoSnapshot.isAcceptableOrUnknown(
          data['roll_no_snapshot']!,
          _rollNoSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rollNoSnapshotMeta);
    }
    if (data.containsKey('name_snapshot')) {
      context.handle(
        _nameSnapshotMeta,
        nameSnapshot.isAcceptableOrUnknown(
          data['name_snapshot']!,
          _nameSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameSnapshotMeta);
    }
    if (data.containsKey('institution_snapshot')) {
      context.handle(
        _institutionSnapshotMeta,
        institutionSnapshot.isAcceptableOrUnknown(
          data['institution_snapshot']!,
          _institutionSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionSnapshotMeta);
    }
    if (data.containsKey('boarding_point_snapshot')) {
      context.handle(
        _boardingPointSnapshotMeta,
        boardingPointSnapshot.isAcceptableOrUnknown(
          data['boarding_point_snapshot']!,
          _boardingPointSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boardingPointSnapshotMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('scanned_barcode')) {
      context.handle(
        _scannedBarcodeMeta,
        scannedBarcode.isAcceptableOrUnknown(
          data['scanned_barcode']!,
          _scannedBarcodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scannedBarcodeMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}student_id'],
      )!,
      rollNoSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roll_no_snapshot'],
      )!,
      nameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_snapshot'],
      )!,
      institutionSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_snapshot'],
      )!,
      boardingPointSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}boarding_point_snapshot'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scannedBarcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scanned_barcode'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      )!,
    );
  }

  @override
  $AttendanceRecordsTable createAlias(String alias) {
    return $AttendanceRecordsTable(attachedDatabase, alias);
  }
}

class AttendanceRecord extends DataClass
    implements Insertable<AttendanceRecord> {
  final int id;
  final int sessionId;
  final int studentId;
  final String rollNoSnapshot;
  final String nameSnapshot;
  final String institutionSnapshot;
  final String boardingPointSnapshot;
  final String status;
  final String scannedBarcode;
  final DateTime scannedAt;
  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.rollNoSnapshot,
    required this.nameSnapshot,
    required this.institutionSnapshot,
    required this.boardingPointSnapshot,
    required this.status,
    required this.scannedBarcode,
    required this.scannedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['student_id'] = Variable<int>(studentId);
    map['roll_no_snapshot'] = Variable<String>(rollNoSnapshot);
    map['name_snapshot'] = Variable<String>(nameSnapshot);
    map['institution_snapshot'] = Variable<String>(institutionSnapshot);
    map['boarding_point_snapshot'] = Variable<String>(boardingPointSnapshot);
    map['status'] = Variable<String>(status);
    map['scanned_barcode'] = Variable<String>(scannedBarcode);
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    return map;
  }

  AttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      studentId: Value(studentId),
      rollNoSnapshot: Value(rollNoSnapshot),
      nameSnapshot: Value(nameSnapshot),
      institutionSnapshot: Value(institutionSnapshot),
      boardingPointSnapshot: Value(boardingPointSnapshot),
      status: Value(status),
      scannedBarcode: Value(scannedBarcode),
      scannedAt: Value(scannedAt),
    );
  }

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRecord(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      studentId: serializer.fromJson<int>(json['studentId']),
      rollNoSnapshot: serializer.fromJson<String>(json['rollNoSnapshot']),
      nameSnapshot: serializer.fromJson<String>(json['nameSnapshot']),
      institutionSnapshot: serializer.fromJson<String>(
        json['institutionSnapshot'],
      ),
      boardingPointSnapshot: serializer.fromJson<String>(
        json['boardingPointSnapshot'],
      ),
      status: serializer.fromJson<String>(json['status']),
      scannedBarcode: serializer.fromJson<String>(json['scannedBarcode']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'studentId': serializer.toJson<int>(studentId),
      'rollNoSnapshot': serializer.toJson<String>(rollNoSnapshot),
      'nameSnapshot': serializer.toJson<String>(nameSnapshot),
      'institutionSnapshot': serializer.toJson<String>(institutionSnapshot),
      'boardingPointSnapshot': serializer.toJson<String>(boardingPointSnapshot),
      'status': serializer.toJson<String>(status),
      'scannedBarcode': serializer.toJson<String>(scannedBarcode),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
    };
  }

  AttendanceRecord copyWith({
    int? id,
    int? sessionId,
    int? studentId,
    String? rollNoSnapshot,
    String? nameSnapshot,
    String? institutionSnapshot,
    String? boardingPointSnapshot,
    String? status,
    String? scannedBarcode,
    DateTime? scannedAt,
  }) => AttendanceRecord(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    studentId: studentId ?? this.studentId,
    rollNoSnapshot: rollNoSnapshot ?? this.rollNoSnapshot,
    nameSnapshot: nameSnapshot ?? this.nameSnapshot,
    institutionSnapshot: institutionSnapshot ?? this.institutionSnapshot,
    boardingPointSnapshot: boardingPointSnapshot ?? this.boardingPointSnapshot,
    status: status ?? this.status,
    scannedBarcode: scannedBarcode ?? this.scannedBarcode,
    scannedAt: scannedAt ?? this.scannedAt,
  );
  AttendanceRecord copyWithCompanion(AttendanceRecordsCompanion data) {
    return AttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      rollNoSnapshot: data.rollNoSnapshot.present
          ? data.rollNoSnapshot.value
          : this.rollNoSnapshot,
      nameSnapshot: data.nameSnapshot.present
          ? data.nameSnapshot.value
          : this.nameSnapshot,
      institutionSnapshot: data.institutionSnapshot.present
          ? data.institutionSnapshot.value
          : this.institutionSnapshot,
      boardingPointSnapshot: data.boardingPointSnapshot.present
          ? data.boardingPointSnapshot.value
          : this.boardingPointSnapshot,
      status: data.status.present ? data.status.value : this.status,
      scannedBarcode: data.scannedBarcode.present
          ? data.scannedBarcode.value
          : this.scannedBarcode,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecord(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('rollNoSnapshot: $rollNoSnapshot, ')
          ..write('nameSnapshot: $nameSnapshot, ')
          ..write('institutionSnapshot: $institutionSnapshot, ')
          ..write('boardingPointSnapshot: $boardingPointSnapshot, ')
          ..write('status: $status, ')
          ..write('scannedBarcode: $scannedBarcode, ')
          ..write('scannedAt: $scannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    studentId,
    rollNoSnapshot,
    nameSnapshot,
    institutionSnapshot,
    boardingPointSnapshot,
    status,
    scannedBarcode,
    scannedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRecord &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.studentId == this.studentId &&
          other.rollNoSnapshot == this.rollNoSnapshot &&
          other.nameSnapshot == this.nameSnapshot &&
          other.institutionSnapshot == this.institutionSnapshot &&
          other.boardingPointSnapshot == this.boardingPointSnapshot &&
          other.status == this.status &&
          other.scannedBarcode == this.scannedBarcode &&
          other.scannedAt == this.scannedAt);
}

class AttendanceRecordsCompanion extends UpdateCompanion<AttendanceRecord> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> studentId;
  final Value<String> rollNoSnapshot;
  final Value<String> nameSnapshot;
  final Value<String> institutionSnapshot;
  final Value<String> boardingPointSnapshot;
  final Value<String> status;
  final Value<String> scannedBarcode;
  final Value<DateTime> scannedAt;
  const AttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.rollNoSnapshot = const Value.absent(),
    this.nameSnapshot = const Value.absent(),
    this.institutionSnapshot = const Value.absent(),
    this.boardingPointSnapshot = const Value.absent(),
    this.status = const Value.absent(),
    this.scannedBarcode = const Value.absent(),
    this.scannedAt = const Value.absent(),
  });
  AttendanceRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int studentId,
    required String rollNoSnapshot,
    required String nameSnapshot,
    required String institutionSnapshot,
    required String boardingPointSnapshot,
    required String status,
    required String scannedBarcode,
    required DateTime scannedAt,
  }) : sessionId = Value(sessionId),
       studentId = Value(studentId),
       rollNoSnapshot = Value(rollNoSnapshot),
       nameSnapshot = Value(nameSnapshot),
       institutionSnapshot = Value(institutionSnapshot),
       boardingPointSnapshot = Value(boardingPointSnapshot),
       status = Value(status),
       scannedBarcode = Value(scannedBarcode),
       scannedAt = Value(scannedAt);
  static Insertable<AttendanceRecord> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? studentId,
    Expression<String>? rollNoSnapshot,
    Expression<String>? nameSnapshot,
    Expression<String>? institutionSnapshot,
    Expression<String>? boardingPointSnapshot,
    Expression<String>? status,
    Expression<String>? scannedBarcode,
    Expression<DateTime>? scannedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (studentId != null) 'student_id': studentId,
      if (rollNoSnapshot != null) 'roll_no_snapshot': rollNoSnapshot,
      if (nameSnapshot != null) 'name_snapshot': nameSnapshot,
      if (institutionSnapshot != null)
        'institution_snapshot': institutionSnapshot,
      if (boardingPointSnapshot != null)
        'boarding_point_snapshot': boardingPointSnapshot,
      if (status != null) 'status': status,
      if (scannedBarcode != null) 'scanned_barcode': scannedBarcode,
      if (scannedAt != null) 'scanned_at': scannedAt,
    });
  }

  AttendanceRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? studentId,
    Value<String>? rollNoSnapshot,
    Value<String>? nameSnapshot,
    Value<String>? institutionSnapshot,
    Value<String>? boardingPointSnapshot,
    Value<String>? status,
    Value<String>? scannedBarcode,
    Value<DateTime>? scannedAt,
  }) {
    return AttendanceRecordsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      rollNoSnapshot: rollNoSnapshot ?? this.rollNoSnapshot,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      institutionSnapshot: institutionSnapshot ?? this.institutionSnapshot,
      boardingPointSnapshot:
          boardingPointSnapshot ?? this.boardingPointSnapshot,
      status: status ?? this.status,
      scannedBarcode: scannedBarcode ?? this.scannedBarcode,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<int>(studentId.value);
    }
    if (rollNoSnapshot.present) {
      map['roll_no_snapshot'] = Variable<String>(rollNoSnapshot.value);
    }
    if (nameSnapshot.present) {
      map['name_snapshot'] = Variable<String>(nameSnapshot.value);
    }
    if (institutionSnapshot.present) {
      map['institution_snapshot'] = Variable<String>(institutionSnapshot.value);
    }
    if (boardingPointSnapshot.present) {
      map['boarding_point_snapshot'] = Variable<String>(
        boardingPointSnapshot.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scannedBarcode.present) {
      map['scanned_barcode'] = Variable<String>(scannedBarcode.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('rollNoSnapshot: $rollNoSnapshot, ')
          ..write('nameSnapshot: $nameSnapshot, ')
          ..write('institutionSnapshot: $institutionSnapshot, ')
          ..write('boardingPointSnapshot: $boardingPointSnapshot, ')
          ..write('status: $status, ')
          ..write('scannedBarcode: $scannedBarcode, ')
          ..write('scannedAt: $scannedAt')
          ..write(')'))
        .toString();
  }
}

class $AttendanceSessionRosterTable extends AttendanceSessionRoster
    with TableInfo<$AttendanceSessionRosterTable, AttendanceSessionRosterData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceSessionRosterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendance_sessions (id)',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<int> studentId = GeneratedColumn<int>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rollNoMeta = const VerificationMeta('rollNo');
  @override
  late final GeneratedColumn<String> rollNo = GeneratedColumn<String>(
    'roll_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardingPointMeta = const VerificationMeta(
    'boardingPoint',
  );
  @override
  late final GeneratedColumn<String> boardingPoint = GeneratedColumn<String>(
    'boarding_point',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    studentId,
    rollNo,
    name,
    institution,
    boardingPoint,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_session_roster';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceSessionRosterData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('roll_no')) {
      context.handle(
        _rollNoMeta,
        rollNo.isAcceptableOrUnknown(data['roll_no']!, _rollNoMeta),
      );
    } else if (isInserting) {
      context.missing(_rollNoMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionMeta);
    }
    if (data.containsKey('boarding_point')) {
      context.handle(
        _boardingPointMeta,
        boardingPoint.isAcceptableOrUnknown(
          data['boarding_point']!,
          _boardingPointMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boardingPointMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, studentId},
  ];
  @override
  AttendanceSessionRosterData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceSessionRosterData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}student_id'],
      )!,
      rollNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roll_no'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      )!,
      boardingPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}boarding_point'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttendanceSessionRosterTable createAlias(String alias) {
    return $AttendanceSessionRosterTable(attachedDatabase, alias);
  }
}

class AttendanceSessionRosterData extends DataClass
    implements Insertable<AttendanceSessionRosterData> {
  final int id;
  final int sessionId;
  final int studentId;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
  final DateTime createdAt;
  const AttendanceSessionRosterData({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['student_id'] = Variable<int>(studentId);
    map['roll_no'] = Variable<String>(rollNo);
    map['name'] = Variable<String>(name);
    map['institution'] = Variable<String>(institution);
    map['boarding_point'] = Variable<String>(boardingPoint);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttendanceSessionRosterCompanion toCompanion(bool nullToAbsent) {
    return AttendanceSessionRosterCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      studentId: Value(studentId),
      rollNo: Value(rollNo),
      name: Value(name),
      institution: Value(institution),
      boardingPoint: Value(boardingPoint),
      createdAt: Value(createdAt),
    );
  }

  factory AttendanceSessionRosterData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceSessionRosterData(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      studentId: serializer.fromJson<int>(json['studentId']),
      rollNo: serializer.fromJson<String>(json['rollNo']),
      name: serializer.fromJson<String>(json['name']),
      institution: serializer.fromJson<String>(json['institution']),
      boardingPoint: serializer.fromJson<String>(json['boardingPoint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'studentId': serializer.toJson<int>(studentId),
      'rollNo': serializer.toJson<String>(rollNo),
      'name': serializer.toJson<String>(name),
      'institution': serializer.toJson<String>(institution),
      'boardingPoint': serializer.toJson<String>(boardingPoint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttendanceSessionRosterData copyWith({
    int? id,
    int? sessionId,
    int? studentId,
    String? rollNo,
    String? name,
    String? institution,
    String? boardingPoint,
    DateTime? createdAt,
  }) => AttendanceSessionRosterData(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    studentId: studentId ?? this.studentId,
    rollNo: rollNo ?? this.rollNo,
    name: name ?? this.name,
    institution: institution ?? this.institution,
    boardingPoint: boardingPoint ?? this.boardingPoint,
    createdAt: createdAt ?? this.createdAt,
  );
  AttendanceSessionRosterData copyWithCompanion(
    AttendanceSessionRosterCompanion data,
  ) {
    return AttendanceSessionRosterData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      rollNo: data.rollNo.present ? data.rollNo.value : this.rollNo,
      name: data.name.present ? data.name.value : this.name,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      boardingPoint: data.boardingPoint.present
          ? data.boardingPoint.value
          : this.boardingPoint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSessionRosterData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('rollNo: $rollNo, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('boardingPoint: $boardingPoint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    studentId,
    rollNo,
    name,
    institution,
    boardingPoint,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceSessionRosterData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.studentId == this.studentId &&
          other.rollNo == this.rollNo &&
          other.name == this.name &&
          other.institution == this.institution &&
          other.boardingPoint == this.boardingPoint &&
          other.createdAt == this.createdAt);
}

class AttendanceSessionRosterCompanion
    extends UpdateCompanion<AttendanceSessionRosterData> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> studentId;
  final Value<String> rollNo;
  final Value<String> name;
  final Value<String> institution;
  final Value<String> boardingPoint;
  final Value<DateTime> createdAt;
  const AttendanceSessionRosterCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.rollNo = const Value.absent(),
    this.name = const Value.absent(),
    this.institution = const Value.absent(),
    this.boardingPoint = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttendanceSessionRosterCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int studentId,
    required String rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
    required DateTime createdAt,
  }) : sessionId = Value(sessionId),
       studentId = Value(studentId),
       rollNo = Value(rollNo),
       name = Value(name),
       institution = Value(institution),
       boardingPoint = Value(boardingPoint),
       createdAt = Value(createdAt);
  static Insertable<AttendanceSessionRosterData> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? studentId,
    Expression<String>? rollNo,
    Expression<String>? name,
    Expression<String>? institution,
    Expression<String>? boardingPoint,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (studentId != null) 'student_id': studentId,
      if (rollNo != null) 'roll_no': rollNo,
      if (name != null) 'name': name,
      if (institution != null) 'institution': institution,
      if (boardingPoint != null) 'boarding_point': boardingPoint,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttendanceSessionRosterCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? studentId,
    Value<String>? rollNo,
    Value<String>? name,
    Value<String>? institution,
    Value<String>? boardingPoint,
    Value<DateTime>? createdAt,
  }) {
    return AttendanceSessionRosterCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      rollNo: rollNo ?? this.rollNo,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      boardingPoint: boardingPoint ?? this.boardingPoint,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<int>(studentId.value);
    }
    if (rollNo.present) {
      map['roll_no'] = Variable<String>(rollNo.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (boardingPoint.present) {
      map['boarding_point'] = Variable<String>(boardingPoint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSessionRosterCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('rollNo: $rollNo, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('boardingPoint: $boardingPoint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StudentsTable students = $StudentsTable(this);
  late final $AttendanceSessionsTable attendanceSessions =
      $AttendanceSessionsTable(this);
  late final $AttendanceRecordsTable attendanceRecords =
      $AttendanceRecordsTable(this);
  late final $AttendanceSessionRosterTable attendanceSessionRoster =
      $AttendanceSessionRosterTable(this);
  late final Index idxAttendanceRecordsSessionStudent = Index(
    'idx_attendance_records_session_student',
    'CREATE UNIQUE INDEX idx_attendance_records_session_student ON attendance_records (session_id, student_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    students,
    attendanceSessions,
    attendanceRecords,
    attendanceSessionRoster,
    idxAttendanceRecordsSessionStudent,
  ];
}

typedef $$StudentsTableCreateCompanionBuilder =
    StudentsCompanion Function({
      Value<int> id,
      required String rollNo,
      required String name,
      required String institution,
      required String boardingPoint,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
    });
typedef $$StudentsTableUpdateCompanionBuilder =
    StudentsCompanion Function({
      Value<int> id,
      Value<String> rollNo,
      Value<String> name,
      Value<String> institution,
      Value<String> boardingPoint,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });

final class $$StudentsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTable, Student> {
  $$StudentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AttendanceRecordsTable, List<AttendanceRecord>>
  _attendanceRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceRecords,
        aliasName: 'students__id__attendance_records__student_id',
      );

  $$AttendanceRecordsTableProcessedTableManager get attendanceRecordsRefs {
    final manager = $$AttendanceRecordsTableTableManager(
      $_db,
      $_db.attendanceRecords,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudentsTableFilterComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rollNo => $composableBuilder(
    column: $table.rollNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> attendanceRecordsRefs(
    Expression<bool> Function($$AttendanceRecordsTableFilterComposer f) f,
  ) {
    final $$AttendanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attendanceRecords,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rollNo => $composableBuilder(
    column: $table.rollNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rollNo =>
      $composableBuilder(column: $table.rollNo, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> attendanceRecordsRefs<T extends Object>(
    Expression<T> Function($$AttendanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$AttendanceRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceRecords,
          getReferencedColumn: (t) => t.studentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StudentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentsTable,
          Student,
          $$StudentsTableFilterComposer,
          $$StudentsTableOrderingComposer,
          $$StudentsTableAnnotationComposer,
          $$StudentsTableCreateCompanionBuilder,
          $$StudentsTableUpdateCompanionBuilder,
          (Student, $$StudentsTableReferences),
          Student,
          PrefetchHooks Function({bool attendanceRecordsRefs})
        > {
  $$StudentsTableTableManager(_$AppDatabase db, $StudentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> rollNo = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<String> boardingPoint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => StudentsCompanion(
                id: id,
                rollNo: rollNo,
                name: name,
                institution: institution,
                boardingPoint: boardingPoint,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String rollNo,
                required String name,
                required String institution,
                required String boardingPoint,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => StudentsCompanion.insert(
                id: id,
                rollNo: rollNo,
                name: name,
                institution: institution,
                boardingPoint: boardingPoint,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attendanceRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (attendanceRecordsRefs) db.attendanceRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (attendanceRecordsRefs)
                    await $_getPrefetchedData<
                      Student,
                      $StudentsTable,
                      AttendanceRecord
                    >(
                      currentTable: table,
                      referencedTable: $$StudentsTableReferences
                          ._attendanceRecordsRefsTable(db),
                      managerFromTypedResult: (p0) => $$StudentsTableReferences(
                        db,
                        table,
                        p0,
                      ).attendanceRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.studentId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$StudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentsTable,
      Student,
      $$StudentsTableFilterComposer,
      $$StudentsTableOrderingComposer,
      $$StudentsTableAnnotationComposer,
      $$StudentsTableCreateCompanionBuilder,
      $$StudentsTableUpdateCompanionBuilder,
      (Student, $$StudentsTableReferences),
      Student,
      PrefetchHooks Function({bool attendanceRecordsRefs})
    >;
typedef $$AttendanceSessionsTableCreateCompanionBuilder =
    AttendanceSessionsCompanion Function({
      Value<int> id,
      required DateTime attendanceDate,
      required String status,
      required DateTime createdAt,
      Value<DateTime?> endedAt,
      Value<String> tripType,
    });
typedef $$AttendanceSessionsTableUpdateCompanionBuilder =
    AttendanceSessionsCompanion Function({
      Value<int> id,
      Value<DateTime> attendanceDate,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> endedAt,
      Value<String> tripType,
    });

final class $$AttendanceSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceSessionsTable,
          AttendanceSession
        > {
  $$AttendanceSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$AttendanceRecordsTable, List<AttendanceRecord>>
  _attendanceRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceRecords,
        aliasName: 'attendance_sessions__id__attendance_records__session_id',
      );

  $$AttendanceRecordsTableProcessedTableManager get attendanceRecordsRefs {
    final manager = $$AttendanceRecordsTableTableManager(
      $_db,
      $_db.attendanceRecords,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $AttendanceSessionRosterTable,
    List<AttendanceSessionRosterData>
  >
  _attendanceSessionRosterRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceSessionRoster,
        aliasName:
            'attendance_sessions__id__attendance_session_roster__session_id',
      );

  $$AttendanceSessionRosterTableProcessedTableManager
  get attendanceSessionRosterRefs {
    final manager = $$AttendanceSessionRosterTableTableManager(
      $_db,
      $_db.attendanceSessionRoster,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceSessionRosterRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttendanceSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceSessionsTable> {
  $$AttendanceSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripType => $composableBuilder(
    column: $table.tripType,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> attendanceRecordsRefs(
    Expression<bool> Function($$AttendanceRecordsTableFilterComposer f) f,
  ) {
    final $$AttendanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attendanceRecords,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attendanceSessionRosterRefs(
    Expression<bool> Function($$AttendanceSessionRosterTableFilterComposer f) f,
  ) {
    final $$AttendanceSessionRosterTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceSessionRoster,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceSessionRosterTableFilterComposer(
                $db: $db,
                $table: $db.attendanceSessionRoster,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AttendanceSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceSessionsTable> {
  $$AttendanceSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripType => $composableBuilder(
    column: $table.tripType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttendanceSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceSessionsTable> {
  $$AttendanceSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get tripType =>
      $composableBuilder(column: $table.tripType, builder: (column) => column);

  Expression<T> attendanceRecordsRefs<T extends Object>(
    Expression<T> Function($$AttendanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$AttendanceRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceRecords,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> attendanceSessionRosterRefs<T extends Object>(
    Expression<T> Function($$AttendanceSessionRosterTableAnnotationComposer a)
    f,
  ) {
    final $$AttendanceSessionRosterTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceSessionRoster,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceSessionRosterTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceSessionRoster,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AttendanceSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceSessionsTable,
          AttendanceSession,
          $$AttendanceSessionsTableFilterComposer,
          $$AttendanceSessionsTableOrderingComposer,
          $$AttendanceSessionsTableAnnotationComposer,
          $$AttendanceSessionsTableCreateCompanionBuilder,
          $$AttendanceSessionsTableUpdateCompanionBuilder,
          (AttendanceSession, $$AttendanceSessionsTableReferences),
          AttendanceSession,
          PrefetchHooks Function({
            bool attendanceRecordsRefs,
            bool attendanceSessionRosterRefs,
          })
        > {
  $$AttendanceSessionsTableTableManager(
    _$AppDatabase db,
    $AttendanceSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> attendanceDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> tripType = const Value.absent(),
              }) => AttendanceSessionsCompanion(
                id: id,
                attendanceDate: attendanceDate,
                status: status,
                createdAt: createdAt,
                endedAt: endedAt,
                tripType: tripType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime attendanceDate,
                required String status,
                required DateTime createdAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> tripType = const Value.absent(),
              }) => AttendanceSessionsCompanion.insert(
                id: id,
                attendanceDate: attendanceDate,
                status: status,
                createdAt: createdAt,
                endedAt: endedAt,
                tripType: tripType,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttendanceSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                attendanceRecordsRefs = false,
                attendanceSessionRosterRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attendanceRecordsRefs) db.attendanceRecords,
                    if (attendanceSessionRosterRefs) db.attendanceSessionRoster,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attendanceRecordsRefs)
                        await $_getPrefetchedData<
                          AttendanceSession,
                          $AttendanceSessionsTable,
                          AttendanceRecord
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceSessionsTableReferences
                              ._attendanceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attendanceSessionRosterRefs)
                        await $_getPrefetchedData<
                          AttendanceSession,
                          $AttendanceSessionsTable,
                          AttendanceSessionRosterData
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceSessionsTableReferences
                              ._attendanceSessionRosterRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceSessionRosterRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AttendanceSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceSessionsTable,
      AttendanceSession,
      $$AttendanceSessionsTableFilterComposer,
      $$AttendanceSessionsTableOrderingComposer,
      $$AttendanceSessionsTableAnnotationComposer,
      $$AttendanceSessionsTableCreateCompanionBuilder,
      $$AttendanceSessionsTableUpdateCompanionBuilder,
      (AttendanceSession, $$AttendanceSessionsTableReferences),
      AttendanceSession,
      PrefetchHooks Function({
        bool attendanceRecordsRefs,
        bool attendanceSessionRosterRefs,
      })
    >;
typedef $$AttendanceRecordsTableCreateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int studentId,
      required String rollNoSnapshot,
      required String nameSnapshot,
      required String institutionSnapshot,
      required String boardingPointSnapshot,
      required String status,
      required String scannedBarcode,
      required DateTime scannedAt,
    });
typedef $$AttendanceRecordsTableUpdateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> studentId,
      Value<String> rollNoSnapshot,
      Value<String> nameSnapshot,
      Value<String> institutionSnapshot,
      Value<String> boardingPointSnapshot,
      Value<String> status,
      Value<String> scannedBarcode,
      Value<DateTime> scannedAt,
    });

final class $$AttendanceRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord
        > {
  $$AttendanceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AttendanceSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .attendanceSessions
      .createAlias('attendance_records__session_id__attendance_sessions__id');

  $$AttendanceSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$AttendanceSessionsTableTableManager(
      $_db,
      $_db.attendanceSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias('attendance_records__student_id__students__id');

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<int>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rollNoSnapshot => $composableBuilder(
    column: $table.rollNoSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institutionSnapshot => $composableBuilder(
    column: $table.institutionSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardingPointSnapshot => $composableBuilder(
    column: $table.boardingPointSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scannedBarcode => $composableBuilder(
    column: $table.scannedBarcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AttendanceSessionsTableFilterComposer get sessionId {
    final $$AttendanceSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.attendanceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceSessionsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rollNoSnapshot => $composableBuilder(
    column: $table.rollNoSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institutionSnapshot => $composableBuilder(
    column: $table.institutionSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardingPointSnapshot => $composableBuilder(
    column: $table.boardingPointSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scannedBarcode => $composableBuilder(
    column: $table.scannedBarcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttendanceSessionsTableOrderingComposer get sessionId {
    final $$AttendanceSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.attendanceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rollNoSnapshot => $composableBuilder(
    column: $table.rollNoSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameSnapshot => $composableBuilder(
    column: $table.nameSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get institutionSnapshot => $composableBuilder(
    column: $table.institutionSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get boardingPointSnapshot => $composableBuilder(
    column: $table.boardingPointSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get scannedBarcode => $composableBuilder(
    column: $table.scannedBarcode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  $$AttendanceSessionsTableAnnotationComposer get sessionId {
    final $$AttendanceSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.attendanceSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord,
          $$AttendanceRecordsTableFilterComposer,
          $$AttendanceRecordsTableOrderingComposer,
          $$AttendanceRecordsTableAnnotationComposer,
          $$AttendanceRecordsTableCreateCompanionBuilder,
          $$AttendanceRecordsTableUpdateCompanionBuilder,
          (AttendanceRecord, $$AttendanceRecordsTableReferences),
          AttendanceRecord,
          PrefetchHooks Function({bool sessionId, bool studentId})
        > {
  $$AttendanceRecordsTableTableManager(
    _$AppDatabase db,
    $AttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> studentId = const Value.absent(),
                Value<String> rollNoSnapshot = const Value.absent(),
                Value<String> nameSnapshot = const Value.absent(),
                Value<String> institutionSnapshot = const Value.absent(),
                Value<String> boardingPointSnapshot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> scannedBarcode = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
              }) => AttendanceRecordsCompanion(
                id: id,
                sessionId: sessionId,
                studentId: studentId,
                rollNoSnapshot: rollNoSnapshot,
                nameSnapshot: nameSnapshot,
                institutionSnapshot: institutionSnapshot,
                boardingPointSnapshot: boardingPointSnapshot,
                status: status,
                scannedBarcode: scannedBarcode,
                scannedAt: scannedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int studentId,
                required String rollNoSnapshot,
                required String nameSnapshot,
                required String institutionSnapshot,
                required String boardingPointSnapshot,
                required String status,
                required String scannedBarcode,
                required DateTime scannedAt,
              }) => AttendanceRecordsCompanion.insert(
                id: id,
                sessionId: sessionId,
                studentId: studentId,
                rollNoSnapshot: rollNoSnapshot,
                nameSnapshot: nameSnapshot,
                institutionSnapshot: institutionSnapshot,
                boardingPointSnapshot: boardingPointSnapshot,
                status: status,
                scannedBarcode: scannedBarcode,
                scannedAt: scannedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttendanceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, studentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$AttendanceRecordsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$AttendanceRecordsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (studentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.studentId,
                                referencedTable:
                                    $$AttendanceRecordsTableReferences
                                        ._studentIdTable(db),
                                referencedColumn:
                                    $$AttendanceRecordsTableReferences
                                        ._studentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceRecordsTable,
      AttendanceRecord,
      $$AttendanceRecordsTableFilterComposer,
      $$AttendanceRecordsTableOrderingComposer,
      $$AttendanceRecordsTableAnnotationComposer,
      $$AttendanceRecordsTableCreateCompanionBuilder,
      $$AttendanceRecordsTableUpdateCompanionBuilder,
      (AttendanceRecord, $$AttendanceRecordsTableReferences),
      AttendanceRecord,
      PrefetchHooks Function({bool sessionId, bool studentId})
    >;
typedef $$AttendanceSessionRosterTableCreateCompanionBuilder =
    AttendanceSessionRosterCompanion Function({
      Value<int> id,
      required int sessionId,
      required int studentId,
      required String rollNo,
      required String name,
      required String institution,
      required String boardingPoint,
      required DateTime createdAt,
    });
typedef $$AttendanceSessionRosterTableUpdateCompanionBuilder =
    AttendanceSessionRosterCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> studentId,
      Value<String> rollNo,
      Value<String> name,
      Value<String> institution,
      Value<String> boardingPoint,
      Value<DateTime> createdAt,
    });

final class $$AttendanceSessionRosterTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceSessionRosterTable,
          AttendanceSessionRosterData
        > {
  $$AttendanceSessionRosterTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AttendanceSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.attendanceSessions.createAlias(
        'attendance_session_roster__session_id__attendance_sessions__id',
      );

  $$AttendanceSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$AttendanceSessionsTableTableManager(
      $_db,
      $_db.attendanceSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttendanceSessionRosterTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceSessionRosterTable> {
  $$AttendanceSessionRosterTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rollNo => $composableBuilder(
    column: $table.rollNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AttendanceSessionsTableFilterComposer get sessionId {
    final $$AttendanceSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.attendanceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceSessionsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceSessionRosterTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceSessionRosterTable> {
  $$AttendanceSessionRosterTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rollNo => $composableBuilder(
    column: $table.rollNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttendanceSessionsTableOrderingComposer get sessionId {
    final $$AttendanceSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.attendanceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceSessionRosterTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceSessionRosterTable> {
  $$AttendanceSessionRosterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get rollNo =>
      $composableBuilder(column: $table.rollNo, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get boardingPoint => $composableBuilder(
    column: $table.boardingPoint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AttendanceSessionsTableAnnotationComposer get sessionId {
    final $$AttendanceSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.attendanceSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$AttendanceSessionRosterTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceSessionRosterTable,
          AttendanceSessionRosterData,
          $$AttendanceSessionRosterTableFilterComposer,
          $$AttendanceSessionRosterTableOrderingComposer,
          $$AttendanceSessionRosterTableAnnotationComposer,
          $$AttendanceSessionRosterTableCreateCompanionBuilder,
          $$AttendanceSessionRosterTableUpdateCompanionBuilder,
          (
            AttendanceSessionRosterData,
            $$AttendanceSessionRosterTableReferences,
          ),
          AttendanceSessionRosterData,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AttendanceSessionRosterTableTableManager(
    _$AppDatabase db,
    $AttendanceSessionRosterTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceSessionRosterTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AttendanceSessionRosterTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AttendanceSessionRosterTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> studentId = const Value.absent(),
                Value<String> rollNo = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<String> boardingPoint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttendanceSessionRosterCompanion(
                id: id,
                sessionId: sessionId,
                studentId: studentId,
                rollNo: rollNo,
                name: name,
                institution: institution,
                boardingPoint: boardingPoint,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int studentId,
                required String rollNo,
                required String name,
                required String institution,
                required String boardingPoint,
                required DateTime createdAt,
              }) => AttendanceSessionRosterCompanion.insert(
                id: id,
                sessionId: sessionId,
                studentId: studentId,
                rollNo: rollNo,
                name: name,
                institution: institution,
                boardingPoint: boardingPoint,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttendanceSessionRosterTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$AttendanceSessionRosterTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$AttendanceSessionRosterTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttendanceSessionRosterTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceSessionRosterTable,
      AttendanceSessionRosterData,
      $$AttendanceSessionRosterTableFilterComposer,
      $$AttendanceSessionRosterTableOrderingComposer,
      $$AttendanceSessionRosterTableAnnotationComposer,
      $$AttendanceSessionRosterTableCreateCompanionBuilder,
      $$AttendanceSessionRosterTableUpdateCompanionBuilder,
      (AttendanceSessionRosterData, $$AttendanceSessionRosterTableReferences),
      AttendanceSessionRosterData,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db, _db.students);
  $$AttendanceSessionsTableTableManager get attendanceSessions =>
      $$AttendanceSessionsTableTableManager(_db, _db.attendanceSessions);
  $$AttendanceRecordsTableTableManager get attendanceRecords =>
      $$AttendanceRecordsTableTableManager(_db, _db.attendanceRecords);
  $$AttendanceSessionRosterTableTableManager get attendanceSessionRoster =>
      $$AttendanceSessionRosterTableTableManager(
        _db,
        _db.attendanceSessionRoster,
      );
}
