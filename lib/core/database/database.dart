import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Students,
    AttendanceSessions,
    AttendanceRecords,
    AttendanceSessionRoster,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());
  static final AppDatabase instance = AppDatabase._();

  /// Builds a database on a caller-supplied executor.
  ///
  /// Exists so tests can run against an in-memory database without touching
  /// the on-disk file or `path_provider`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Replays the indexes declared on the tables themselves, read out
        // of the generated schema rather than hand-written as SQL here.
        // That is what guarantees a migrated database ends up structurally
        // identical to a freshly created one: there is no second copy of
        // the statement that could fall out of step with the annotation.
        for (final entity in m.database.allSchemaEntities.whereType<Index>()) {
          await m.createIndex(entity);
        }
      }
      if (from < 3) {
        // The per-session roster snapshot table added for immutable
        // attendance history. Created from the generated table object so a
        // migrated database matches a fresh one exactly.
        await m.createTable(attendanceSessionRoster);
      }
      if (from < 4) {
        // Adds tripType column ('morning' / 'evening') with default 'morning'.
        await m.addColumn(attendanceSessions, attendanceSessions.tripType);
      }
    },
  );

  // Table access — use generated fields directly: $students, $attendanceSessions, $attendanceRecords
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'onboard.db'));
    return NativeDatabase(file);
  });
}
