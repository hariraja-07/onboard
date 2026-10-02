import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../students_controller.dart';
import '../../../core/database/database.dart';
import '../../../core/database/repositories/student_repository.dart';
import 'excel_import_models.dart';
import 'excel_import_service.dart';
import 'excel_template_service.dart';

/// Where the import flow currently is.
enum ImportStatus {
  /// Nothing chosen yet.
  idle,

  /// Waiting on the OS file picker.
  picking,

  /// Reading and classifying the workbook.
  parsing,

  /// Preview is ready and awaiting the user's decision.
  preview,

  /// Writing the confirmed rows.
  importing,

  /// Import finished; [ImportState.summary] holds the outcome.
  done,

  /// The file could not be read at all.
  failed,
}

class ImportState {
  const ImportState({
    this.status = ImportStatus.idle,
    this.preview,
    this.summary,
    this.errorMessage,
  });

  final ImportStatus status;
  final ImportPreview? preview;
  final ImportSummary? summary;
  final String? errorMessage;

  bool get isBusy =>
      status == ImportStatus.picking ||
      status == ImportStatus.parsing ||
      status == ImportStatus.importing;
}

final studentImportControllerProvider = StateNotifierProvider.autoDispose<
    StudentImportController, ImportState>((ref) {
  return StudentImportController(
    studentRepository: ref.watch(studentRepositoryProvider),
    loadStudents: () =>
        ref.read(studentsProvider.notifier).loadStudents(),
  );
});

/// Drives the Excel import: pick a file, classify it, confirm, commit.
class StudentImportController extends StateNotifier<ImportState> {
  StudentImportController({
    required StudentRepository studentRepository,
    required Future<void> Function() loadStudents,
  })  : _students = studentRepository,
        _loadStudents = loadStudents,
        super(const ImportState());

  final StudentRepository _students;
  final Future<void> Function() _loadStudents;

  /// Opens the OS file picker, reads the chosen workbook and builds a preview.
  ///
  /// A cancelled picker is not an error: the state simply returns to
  /// [ImportStatus.idle].
  Future<void> pickAndPreview() async {
    state = const ImportState(status: ImportStatus.picking);

    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
      );
    } catch (error) {
      state = ImportState(
        status: ImportStatus.failed,
        errorMessage: 'Could not open the file picker.\n$error',
      );
      return;
    }

    if (file == null) {
      state = const ImportState();
      return;
    }

    state = const ImportState(status: ImportStatus.parsing);

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (error) {
      state = ImportState(
        status: ImportStatus.failed,
        errorMessage: 'Could not read "${file.name}".\n$error',
      );
      return;
    }

    // Normalising the stored values the same way the parser does is what makes
    // the comparison case- and spacing-insensitive.
    final storedRollNos = await _students.allRollNos();
    final existing = storedRollNos
        .map(ExcelImportService.normaliseRollNo)
        .where((rollNo) => rollNo.isNotEmpty)
        .toSet();

    try {
      // Decoding a workbook is CPU bound and would visibly stall the frame, so
      // it runs off the UI isolate.
      final preview = await compute(
        _parseInBackground,
        _ParseRequest(
          bytes: Uint8List.fromList(bytes),
          fileName: file.name,
          existingRollNos: existing,
        ),
      );
      state = ImportState(status: ImportStatus.preview, preview: preview);
    } on ExcelImportException catch (error) {
      state = ImportState(
        status: ImportStatus.failed,
        errorMessage: error.message,
      );
    } catch (error) {
      state = ImportState(
        status: ImportStatus.failed,
        errorMessage: 'Something went wrong reading that file.\n$error',
      );
    }
  }

  /// Writes the previewed rows. Existing students are never touched, so this
  /// can only ever add rows.
  Future<void> confirmImport() async {
    final preview = state.preview;
    if (preview == null || !preview.canImport) return;

    state = ImportState(status: ImportStatus.importing, preview: preview);

    final now = DateTime.now();
    final entries = [
      for (final draft in preview.newStudents)
        StudentsCompanion.insert(
          rollNo: draft.rollNo,
          name: draft.name,
          institution: draft.institution,
          boardingPoint: draft.boardingPoint,
          createdAt: now,
        ),
    ];

    try {
      await _students.insertAll(entries);
      await _loadStudents();
      state = ImportState(
        status: ImportStatus.done,
        summary: ImportSummary(
          fileName: preview.fileName,
          sheetName: preview.sheetName,
          added: entries.length,
          existingSkipped: preview.existing.length,
          duplicatesSkipped: preview.duplicates.length,
          invalidSkipped: preview.invalid.length,
        ),
      );
    } catch (error) {
      // The transaction rolled back, so nothing was written.
      state = ImportState(
        status: ImportStatus.failed,
        preview: preview,
        errorMessage: 'Import failed, so no students were added.\n$error',
      );
    }
  }

  /// Offers the blank roster template through the platform's save dialog.
  ///
  /// Returns a message for the user, or null when the save was cancelled.
  Future<String?> downloadTemplate() async {
    final bytes = ExcelTemplateService().build();
    if (bytes == null) {
      return 'Could not build the template.';
    }

    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save sample import template',
        fileName: ExcelTemplateService.fileName,
        bytes: Uint8List.fromList(bytes),
      );
      if (saved == null) return null;
      return 'Template saved to $saved';
    } catch (error) {
      return 'Could not save the template.\n$error';
    }
  }

  void reset() => state = const ImportState();
}

/// Message for [compute]; everything here has to be sendable to another
/// isolate, so it holds only primitives and collections of them.
class _ParseRequest {
  const _ParseRequest({
    required this.bytes,
    required this.fileName,
    required this.existingRollNos,
  });

  final Uint8List bytes;
  final String fileName;
  final Set<String> existingRollNos;
}

ImportPreview _parseInBackground(_ParseRequest request) {
  return ExcelImportService().parse(
    request.bytes,
    fileName: request.fileName,
    existingRollNos: request.existingRollNos,
  );
}
