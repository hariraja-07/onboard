import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Students, AttendanceSessions, AttendanceRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());
  static final AppDatabase instance = AppDatabase._();

  /// Builds a database on a caller-supplied executor.
  ///
  /// Exists so tests can run against an in-memory database without touching
  /// the on-disk file or `path_provider`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // Table access — use generated fields directly: $students, $attendanceSessions, $attendanceRecords
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'onboard.db'));
    return NativeDatabase(file);
  });
}