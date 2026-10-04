import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/providers.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/students/import/excel_import_models.dart';
import 'package:onboard/features/students/import/import_controller.dart';
import 'package:onboard/features/students/import/pages/import_students_page.dart';

/// A roster with the four mapped columns plus [ignoredCount] columns OnBoard
/// does not read. Real exports are often far wider than the four columns that
/// matter, and every extra one used to be listed as a chip in the preview
/// header.
ImportPreview buildPreview({int ignoredCount = 20, int studentCount = 12}) {
  return ImportPreview(
    fileName: 'springfield_bus_roster_final_v3.xlsx',
    sheetName: 'Students',
    headerRowNumber: 1,
    detectedColumns: const {
      ImportField.rollNo: 'C',
      ImportField.name: 'D',
      ImportField.institution: 'E',
      ImportField.boardingPoint: 'G',
    },
    ignoredColumns: [
      for (var i = 0; i < ignoredCount; i++)
        IgnoredColumn(letter: 'H$i', columnLabel: 'Unused column $i'),
    ],
    newStudents: [
      for (var i = 0; i < studentCount; i++)
        ImportedStudentDraft(
          rowNumber: i + 2,
          rollNo: '24BMR${(100 + i).toString().padLeft(3, '0')}',
          name: 'Student Number $i',
          institution: 'Springfield College',
          boardingPoint: 'North Gate',
        ),
    ],
    existing: const [],
    duplicates: const [],
    invalid: const [],
    totalDataRows: studentCount,
    skippedEmptyRows: 0,
  );
}

/// [StudentImportController] with a pre-seeded preview, so the preview screen
/// can be rendered without driving the platform file picker.
class _StubbedImportController extends StudentImportController {
  _StubbedImportController({
    required super.studentRepository,
    required ImportPreview preview,
  }) : _preview = preview,
       super(loadStudents: () async {});

  final ImportPreview _preview;

  void showPreview() =>
      state = ImportState(status: ImportStatus.preview, preview: _preview);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StudentRepository students;
  late _StubbedImportController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
  });

  tearDown(() => db.close());

  Widget createSubject({ImportPreview? preview}) {
    controller = _StubbedImportController(
      studentRepository: students,
      preview: preview ?? buildPreview(),
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        studentRepositoryProvider.overrideWithValue(students),
        studentImportControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: ImportStudentsPage()),
    );
  }

  /// Shrinks the surface so a tall header has to compete for vertical space,
  /// which is what a landscape phone or a split-screen window would do.
  void useSmallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> showPreview(WidgetTester tester) async {
    controller.showPreview();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preview does not overflow on a short screen with many ignored columns',
    (tester) async {
      useSmallSurface(tester);

      await tester.pumpWidget(createSubject());
      await showPreview(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ImportStudentsPage), findsOneWidget);
    },
  );

  testWidgets('preview does not overflow at a large text scale', (
    tester,
  ) async {
    useSmallSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(createSubject());
    await showPreview(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('column mapping is collapsed until asked for', (tester) async {
    await tester.pumpWidget(createSubject());
    await showPreview(tester);

    expect(find.text('springfield_bus_roster_final_v3.xlsx'), findsOneWidget);
    expect(find.text('Sheet "Students", header on row 1'), findsOneWidget);
    expect(find.textContaining('Unused column'), findsNothing);
  });

  testWidgets('expanding the mapping caps chips and scrolls the region', (
    tester,
  ) async {
    useSmallSurface(tester);

    await tester.pumpWidget(createSubject());
    await showPreview(tester);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The four mapped columns plus the first six ignored ones are listed, and
    // the remaining 14 collapse into a count rather than 20 separate chips.
    expect(find.textContaining('Unused column'), findsNWidgets(6));
    expect(find.text('+14 more'), findsOneWidget);

    final mapping = find.ancestor(
      of: find.text('+14 more'),
      matching: find.byType(SingleChildScrollView),
    );
    expect(mapping, findsOneWidget);
  });
}
