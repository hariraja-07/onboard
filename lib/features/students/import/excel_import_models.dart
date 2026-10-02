/// The four student fields OnBoard imports from a spreadsheet.
///
/// Mirrors the columns of the `Students` table in `core/database/tables.dart`.
/// The maximum lengths are the same limits the Drift columns enforce, so an
/// over-long value is reported as invalid rather than silently truncated.
enum ImportField {
  rollNo(label: 'Roll No', maxLength: 50),
  name(label: 'Name', maxLength: 100),
  institution(label: 'Institution', maxLength: 150),
  boardingPoint(label: 'Boarding Point', maxLength: 150);

  const ImportField({required this.label, required this.maxLength});

  final String label;
  final int maxLength;
}

/// A row that passed validation and is not already known to the database.
class ImportedStudentDraft {
  const ImportedStudentDraft({
    required this.rowNumber,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
  });

  /// 1-based row number as shown in Excel, so the user can find the row.
  final int rowNumber;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
}

/// A row whose roll number already exists in the database.
///
/// Existing students are never overwritten — this is reported so the user can
/// see exactly which rows were skipped. Editing a changed name or boarding
/// point stays a deliberate, manual action in the Students list.
class ExistingStudentMatch {
  const ExistingStudentMatch({
    required this.rowNumber,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
  });

  final int rowNumber;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
}

/// A row repeating a roll number that already appeared earlier in the same
/// workbook. The first occurrence is the one that is considered.
class DuplicateRowMatch {
  const DuplicateRowMatch({
    required this.rowNumber,
    required this.firstRowNumber,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
  });

  final int rowNumber;
  final int firstRowNumber;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
}

/// A row that failed validation, with the reason it cannot be imported.
class InvalidRowMatch {
  const InvalidRowMatch({
    required this.rowNumber,
    required this.reason,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
  });

  final int rowNumber;
  final String reason;

  /// Raw (normalised but unvalidated) values, so the user can see what was read.
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
}

/// A column present in the spreadsheet that OnBoard deliberately ignores.
class IgnoredColumn {
  const IgnoredColumn({required this.columnLabel, required this.letter});

  /// The header text exactly as it appears in the spreadsheet.
  final String columnLabel;

  /// Spreadsheet column letter, e.g. `A` for `S.NO.`.
  final String letter;
}

/// The result of reading a workbook, shown to the user before anything is
/// written to the database.
class ImportPreview {
  const ImportPreview({
    required this.fileName,
    required this.sheetName,
    required this.headerRowNumber,
    required this.detectedColumns,
    required this.ignoredColumns,
    required this.newStudents,
    required this.existing,
    required this.duplicates,
    required this.invalid,
    required this.totalDataRows,
    required this.skippedEmptyRows,
  });

  final String fileName;
  final String sheetName;

  /// 1-based row number of the detected header.
  final int headerRowNumber;

  /// Field to the column it was read from.
  final Map<ImportField, String> detectedColumns;
  final List<IgnoredColumn> ignoredColumns;

  final List<ImportedStudentDraft> newStudents;
  final List<ExistingStudentMatch> existing;
  final List<DuplicateRowMatch> duplicates;
  final List<InvalidRowMatch> invalid;

  /// Rows that had at least one non-blank value in a mapped column.
  final int totalDataRows;

  /// Rows where every mapped column was blank. These are skipped silently
  /// rather than reported as invalid.
  final int skippedEmptyRows;

  bool get canImport => newStudents.isNotEmpty;

  int get skippedCount => existing.length + duplicates.length + invalid.length;
}

/// The outcome of a committed import.
class ImportSummary {
  const ImportSummary({
    required this.fileName,
    required this.sheetName,
    required this.added,
    required this.existingSkipped,
    required this.duplicatesSkipped,
    required this.invalidSkipped,
  });

  final String fileName;
  final String sheetName;
  final int added;
  final int existingSkipped;
  final int duplicatesSkipped;
  final int invalidSkipped;

  int get skippedCount => existingSkipped + duplicatesSkipped + invalidSkipped;
}

/// Raised when a workbook cannot be read at all, as opposed to containing rows
/// that fail validation. Carries a message meant to be shown to the user.
class ExcelImportException implements Exception {
  const ExcelImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
