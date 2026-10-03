import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

import 'excel_import_models.dart';

/// Reads a student workbook and classifies every row, without touching the
/// database.
///
/// Deliberately free of Flutter and Drift imports so it can be unit tested
/// directly and run inside a background isolate. Callers pass the set of roll
/// numbers already in the database; [existingRollNos] is only read, never
/// modified.
class ExcelImportService {
  const ExcelImportService();

  /// Largest workbook we will attempt to decode. A bus roster is a few hundred
  /// rows, so this is generous while still refusing a mis-picked video.
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// How many rows from the top of a sheet to search for the header. Rosters
  /// often have a title and a blank line above the real header.
  static const int headerScanRows = 10;

  /// Guards against a sheet that is mostly empty formatting.
  static const int maxRows = 50000;

  /// First two bytes of a ZIP archive, which is what .xlsx and .xls are.
  static const int _zipMagic = 0x50;
  static const int _zipMagic2 = 0x4B;

  /// Header spellings accepted for each field. Keys are compared after
  /// [normaliseHeader], so `ROLL NO`, `Roll No.`, `roll_no` and `Roll-No` all
  /// collapse to `rollno` and land in the same bucket.
  static const Map<ImportField, Set<String>> _headerAliases = {
    ImportField.rollNo: {
      'rollno',
      'rollnumber',
      'rollnum',
      'roll',
      'studentrollno',
      'studentrollnumber',
      'regno',
      'registerno',
      'registrationno',
      'enrollmentno',
      'enrolmentno',
      'admissionno',
    },
    ImportField.name: {
      'name',
      'studentname',
      'fullname',
      'student',
      'nameofstudent',
    },
    ImportField.institution: {
      'institution',
      'institutionname',
      'school',
      'schoolname',
      'college',
      'collegename',
      'university',
    },
    ImportField.boardingPoint: {
      'boardingpoint',
      'boarding',
      'boardingpt',
      'boardingpoints',
      // Rosters in the wild spell this "BORDING POINT"; accept both so a file
      // does not have to be corrected before it will import.
      'bordingpoint',
      'bording',
      'bordingpt',
      'pickuppoint',
      'pickup',
      'pickuplocation',
      'stop',
      'stopname',
      'busstop',
      'routepoint',
      'droppoint',
    },
  };

  /// Runs internal whitespace runs to a single space and drops zero-width
  /// characters that survive a copy/paste out of Excel or a PDF.
  static final RegExp _whitespace = RegExp(r'[\s\u200B-\u200D\uFEFF]+');

  /// Everything that is not a lowercase letter or digit is dropped, so
  /// `S.NO.`, `Roll No`, `ROLL_NO` and `roll-no` all normalise identically.
  static final RegExp _nonAlphanumeric = RegExp('[^a-z0-9]');

  /// Lowercase, strip punctuation, for matching against [ImportField].
  static String normaliseHeader(String raw) =>
      raw.toLowerCase().replaceAll(_nonAlphanumeric, '');

  /// Trims and collapses whitespace. Applied to every imported value.
  static String normaliseValue(String raw) =>
      raw.replaceAll(_whitespace, ' ').trim();

  /// Roll numbers are the import's identity key, so they are trimmed,
  /// whitespace-collapsed and upper-cased. This matches the normalisation
  /// `StudentsNotifier.addStudent` applies when a student is added by hand.
  static String normaliseRollNo(String raw) =>
      normaliseValue(raw).toUpperCase();

  /// Parses [bytes] and classifies each row.
  ///
  /// Throws [ExcelImportException] with a user-facing message when the file
  /// cannot be read or does not contain the required columns.
  ImportPreview parse(
    Uint8List bytes, {
    required String fileName,
    required Set<String> existingRollNos,
  }) {
    if (bytes.isEmpty) {
      throw const ExcelImportException('That file is empty.');
    }
    if (bytes.length > maxFileBytes) {
      throw ExcelImportException(
        'That file is too large to import '
        '(${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
        'The limit is ${maxFileBytes ~/ (1024 * 1024)} MB.',
      );
    }
    if (bytes[0] != _zipMagic || bytes[1] != _zipMagic2) {
      throw const ExcelImportException(
        'That is not a spreadsheet. Please choose a .xlsx or .xls file.',
      );
    }

    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const ExcelImportException(
        'Could not read that file. It may be corrupt, or protected with a '
        'password. Try re-saving it from Excel and import again.',
      );
    }

    if (excel.tables.isEmpty) {
      throw const ExcelImportException('That workbook has no worksheets.');
    }

    final located = _locateHeader(excel.tables);
    if (located == null) {
      throw ExcelImportException(_missingColumnsMessage(excel.tables));
    }

    return _classifyRows(
      excel.tables[located.sheetName]!,
      fileName: fileName,
      existingRollNos: existingRollNos,
      located: located,
    );
  }

  /// Picks the worksheet and header row that carry the most required columns.
  ///
  /// Files exported for several buses often contain a cover sheet or a
  /// per-bus breakdown, so every sheet is considered and the best one wins
  /// rather than defaulting to the first.
  _HeaderLocation? _locateHeader(Map<String, Sheet> tables) {
    _HeaderLocation? best;

    for (final entry in tables.entries) {
      final sheet = entry.value;
      if (sheet.maxRows > maxRows) {
        throw ExcelImportException(
          'Sheet "${entry.key}" has more than $maxRows rows, which is beyond '
          'what OnBoard can import. Split the file into smaller sheets.',
        );
      }

      final rows = sheet.rows;
      final limit = rows.length < headerScanRows ? rows.length : headerScanRows;

      for (var rowIndex = 0; rowIndex < limit; rowIndex++) {
        final columns = _matchColumns(rows[rowIndex]);
        final candidate = _HeaderLocation(
          sheetName: entry.key,
          rowIndex: rowIndex,
          columns: columns,
        );

        if (candidate.matchCount == ImportField.values.length) return candidate;

        final currentBest = best?.matchCount ?? 0;
        if (candidate.matchCount > currentBest ||
            (candidate.matchCount == currentBest &&
                candidate.matchCount > 0 &&
                candidate.rowIndex < best!.rowIndex)) {
          best = candidate;
        }
      }
    }

    return best;
  }

  /// Maps the header cells of [headerRow] onto fields, and records the columns
  /// we are ignoring. A header that resolves to no known field and is not a
  /// recognised ignorable column is still reported as ignored, so the preview
  /// can show the user exactly what we read and what we skipped.
  Map<ImportField, int> _matchColumns(List<Data?> headerRow) {
    final columns = <ImportField, int>{};

    for (var columnIndex = 0; columnIndex < headerRow.length; columnIndex++) {
      final raw = _cellToString(headerRow[columnIndex]);
      if (raw.isEmpty) continue;

      final key = normaliseHeader(raw);
      if (key.isEmpty) continue;

      ImportField? field;
      for (final candidate in ImportField.values) {
        if (_headerAliases[candidate]!.contains(key)) {
          field = candidate;
          break;
        }
      }

      // First column wins if a sheet repeats a header, so a stray second
      // "NAME" further right cannot hijack the real one.
      if (field != null) {
        columns.putIfAbsent(field, () => columnIndex);
      }
    }

    return columns;
  }

  /// Builds the preview by walking every row below the detected header.
  ImportPreview _classifyRows(
    Sheet sheet, {
    required String fileName,
    required Set<String> existingRollNos,
    required _HeaderLocation located,
  }) {
    final rows = sheet.rows;
    final columns = located.columns;

    final detected = <ImportField, String>{};
    final headerRow = rows[located.rowIndex];
    for (final entry in columns.entries) {
      detected[entry.key] = _cellToString(headerRow[entry.value]);
    }

    final ignored = <IgnoredColumn>[];
    final used = columns.values.toSet();
    for (var columnIndex = 0; columnIndex < headerRow.length; columnIndex++) {
      if (used.contains(columnIndex)) continue;
      final label = _cellToString(headerRow[columnIndex]);
      if (label.isEmpty) continue;
      ignored.add(
        IgnoredColumn(columnLabel: label, letter: _columnLetter(columnIndex)),
      );
    }

    final newStudents = <ImportedStudentDraft>[];
    final existing = <ExistingStudentMatch>[];
    final duplicates = <DuplicateRowMatch>[];
    final invalid = <InvalidRowMatch>[];

    // Roll numbers already accounted for in this workbook, mapped to the row
    // they first appeared on. Only rows that pass validation are recorded, so
    // a malformed row never blocks a later good one.
    final seenRollNos = <String, int>{};
    var totalDataRows = 0;
    var skippedEmptyRows = 0;

    for (
      var rowIndex = located.rowIndex + 1;
      rowIndex < rows.length;
      rowIndex++
    ) {
      final row = rows[rowIndex];
      final excelRowNumber = rowIndex + 1;

      String read(ImportField field) {
        final columnIndex = columns[field];
        if (columnIndex == null) return '';
        final cell = _readCell(row, columnIndex);
        return field == ImportField.rollNo ? normaliseRollNo(cell) : cell;
      }

      final rollNo = read(ImportField.rollNo);
      final name = read(ImportField.name);
      final institution = read(ImportField.institution);
      final boardingPoint = read(ImportField.boardingPoint);

      if (rollNo.isEmpty &&
          name.isEmpty &&
          institution.isEmpty &&
          boardingPoint.isEmpty) {
        skippedEmptyRows++;
        continue;
      }

      totalDataRows++;

      final reasons = <String>[];
      void check(ImportField field, String value) {
        if (value.isEmpty) {
          reasons.add('${field.label} is missing');
        } else if (value.length > field.maxLength) {
          reasons.add('${field.label} is too long (max ${field.maxLength})');
        }
      }

      check(ImportField.rollNo, rollNo);
      check(ImportField.name, name);
      check(ImportField.institution, institution);
      check(ImportField.boardingPoint, boardingPoint);

      if (reasons.isNotEmpty) {
        invalid.add(
          InvalidRowMatch(
            rowNumber: excelRowNumber,
            reason: reasons.join(', '),
            rollNo: rollNo,
            name: name,
            institution: institution,
            boardingPoint: boardingPoint,
          ),
        );
        continue;
      }

      final firstRow = seenRollNos[rollNo];
      if (firstRow != null) {
        duplicates.add(
          DuplicateRowMatch(
            rowNumber: excelRowNumber,
            firstRowNumber: firstRow,
            rollNo: rollNo,
            name: name,
            institution: institution,
            boardingPoint: boardingPoint,
          ),
        );
        continue;
      }
      seenRollNos[rollNo] = excelRowNumber;

      if (existingRollNos.contains(rollNo)) {
        // Deliberately read-only. Existing students are reported and skipped;
        // OnBoard never overwrites a record through an import.
        existing.add(
          ExistingStudentMatch(
            rowNumber: excelRowNumber,
            rollNo: rollNo,
            name: name,
            institution: institution,
            boardingPoint: boardingPoint,
          ),
        );
        continue;
      }

      newStudents.add(
        ImportedStudentDraft(
          rowNumber: excelRowNumber,
          rollNo: rollNo,
          name: name,
          institution: institution,
          boardingPoint: boardingPoint,
        ),
      );
    }

    return ImportPreview(
      fileName: fileName,
      sheetName: located.sheetName,
      headerRowNumber: located.rowIndex + 1,
      detectedColumns: detected,
      ignoredColumns: ignored,
      newStudents: newStudents,
      existing: existing,
      duplicates: duplicates,
      invalid: invalid,
      totalDataRows: totalDataRows,
      skippedEmptyRows: skippedEmptyRows,
    );
  }

  /// Explains which required columns could not be found, listing the headers
  /// that were present so the user can correct the file.
  String _missingColumnsMessage(Map<String, Sheet> tables) {
    final seen = <String>{};

    for (final sheet in tables.values) {
      final rows = sheet.rows;
      final limit = rows.length < headerScanRows ? rows.length : headerScanRows;
      for (var rowIndex = 0; rowIndex < limit; rowIndex++) {
        for (final cell in rows[rowIndex]) {
          final label = _cellToString(cell);
          if (label.isNotEmpty) seen.add(label);
        }
      }
    }

    final buffer = StringBuffer('Could not find the required columns');
    buffer.write(' (${ImportField.values.map((f) => f.label).join(', ')}) ');
    buffer.write('in this workbook.');

    if (seen.isNotEmpty) {
      final sample = seen.take(12).toList();
      buffer.write(' Found: ${sample.join(', ')}');
      if (seen.length > sample.length) {
        buffer.write(' and ${seen.length - sample.length} more');
      }
      buffer.write('.');
    }
    buffer.write(' Column names are matched loosely, so check the spelling.');

    return buffer.toString();
  }

  /// Reads a cell out of a row, tolerating rows shorter than the sheet width.
  String _cellToString(Data? cell) {
    if (cell == null) return '';

    final value = cell.value;
    if (value == null) return '';

    return switch (value) {
      // `TextCellValue.value` is a TextSpan, so rich text needs flattening.
      TextCellValue(:final value) => _spanToString(value),
      IntCellValue(:final value) => '$value',
      // Roll numbers stored as 101.0 must come back as "101".
      DoubleCellValue(:final value) => _doubleToString(value),
      BoolCellValue(:final value) => value ? 'TRUE' : 'FALSE',
      // Formulas use whatever Excel last cached, so an edited roster still
      // imports the value the user sees on screen.
      FormulaCellValue(:final cachedValue) =>
        _cellValueToString(cachedValue) ?? cell.displayText,
      // Dates and times are never valid student data; show what Excel would.
      _ => cell.displayText,
    };
  }

  String? _cellValueToString(CellValue? value) {
    if (value == null) return null;
    return switch (value) {
      TextCellValue(:final value) => _spanToString(value),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) => _doubleToString(value),
      BoolCellValue(:final value) => value ? 'TRUE' : 'FALSE',
      FormulaCellValue(:final cachedValue) => _cellValueToString(cachedValue),
      _ => null,
    };
  }

  String _spanToString(TextSpan span) {
    final children = span.children;
    if (children == null || children.isEmpty) return span.text ?? '';

    final buffer = StringBuffer(span.text ?? '');
    for (final child in children) {
      buffer.write(_spanToString(child));
    }
    return buffer.toString();
  }

  String _doubleToString(double value) {
    if (!value.isFinite) return '';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Reads and normalises the cell at [columnIndex] of [row].
  ///
  /// Excel omits trailing empty cells, so a row with data only in the first
  /// two columns can be shorter than the header row.
  String _readCell(List<Data?> row, int columnIndex) {
    if (columnIndex < 0 || columnIndex >= row.length) return '';
    return normaliseValue(_cellToString(row[columnIndex]));
  }

  /// Converts a 0-based column index to its spreadsheet letter, so a preview
  /// can say "column G, STAGE".
  String _columnLetter(int columnIndex) {
    var index = columnIndex;
    var letters = '';
    while (index >= 0) {
      letters = String.fromCharCode(65 + (index % 26)) + letters;
      index = (index ~/ 26) - 1;
    }
    return letters;
  }
}

/// Header row index plus the column each required field was found in.
class _HeaderLocation {
  _HeaderLocation({
    required this.sheetName,
    required this.rowIndex,
    required this.columns,
  });

  final String sheetName;
  final int rowIndex;
  final Map<ImportField, int> columns;

  int get matchCount => columns.length;
}
