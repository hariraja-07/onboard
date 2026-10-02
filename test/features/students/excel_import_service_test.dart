import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/features/students/import/excel_import_models.dart';
import 'package:onboard/features/students/import/excel_import_service.dart';

/// Builds an in-memory workbook from rows of cell text and encodes it, so the
/// tests exercise the same decode path a real .xlsx takes.
Uint8List buildWorkbook(
  List<List<dynamic>> rows, {
  String sheetName = 'Students',
  String? defaultSheetName,
}) {
  final excel = Excel.createExcel();
  if (defaultSheetName != null) {
    excel.delete('Sheet1');
    excel.rename(defaultSheetName, sheetName);
  } else {
    excel.rename('Sheet1', sheetName);
  }

  final sheet = excel[sheetName];
  for (final row in rows) {
    sheet.appendRow([
      for (final cell in row)
        if (cell == null) null else TextCellValue(cell.toString()),
    ]);
  }

  final bytes = excel.encode();
  return bytes == null ? Uint8List(0) : Uint8List.fromList(bytes);
}

/// The roster layout the bus operator actually exports.
const _standardHeader = [
  'S.NO.',
  'BUS NO.',
  'ROLL NO',
  'NAME',
  'INSTITUTION',
  'STAGE',
  'BORDING POINT',
];

/// A visually blank row. Note that `appendRow([])` inserts nothing at all, so
/// a blank row has to be spelled out with null cells to exist in the sheet.
List<dynamic> get _blankRow => List<dynamic>.filled(_standardHeader.length, null);

void main() {
  const service = ExcelImportService();

  ImportPreview parse(
    List<List<dynamic>> rows, {
    Set<String> existing = const {},
    String sheetName = 'Students',
    String? defaultSheetName,
  }) {
    return service.parse(
      buildWorkbook(rows, sheetName: sheetName, defaultSheetName: defaultSheetName),
      fileName: 'roster.xlsx',
      existingRollNos: existing,
    );
  }

  group('header detection', () {
    test('reads the four required columns and ignores the rest', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.sheetName, 'Students');
      expect(preview.headerRowNumber, 1);
      expect(preview.detectedColumns[ImportField.rollNo], 'ROLL NO');
      expect(preview.detectedColumns[ImportField.name], 'NAME');
      expect(preview.detectedColumns[ImportField.institution], 'INSTITUTION');
      expect(
        preview.detectedColumns[ImportField.boardingPoint],
        'BORDING POINT',
      );

      expect(
        preview.ignoredColumns.map((c) => c.columnLabel),
        containsAll(['S.NO.', 'BUS NO.', 'STAGE']),
      );
      expect(
        preview.ignoredColumns.firstWhere((c) => c.columnLabel == 'S.NO.').letter,
        'A',
      );

      expect(preview.newStudents.single.rollNo, '101');
      expect(preview.newStudents.single.name, 'Asha Rao');
      expect(preview.newStudents.single.institution, 'Green Valley');
      expect(preview.newStudents.single.boardingPoint, 'North Gate');
    });

    test('tolerates case, punctuation and spacing in header names', () {
      final preview = parse([
        ['  s.no. ', 'bus no.', 'roll_no', 'FULL  NAME', 'Institution.', 'stage', 'Boarding-Point'],
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.newStudents.single.rollNo, '101');
      expect(preview.newStudents.single.name, 'Asha Rao');
      expect(preview.newStudents.single.boardingPoint, 'North Gate');
      expect(
        preview.detectedColumns[ImportField.boardingPoint],
        'Boarding-Point',
      );
    });

    test('accepts alternative header spellings', () {
      final preview = parse([
        ['Serial No', 'Bus Number', 'Registration No', 'Student Name', 'School', 'Stage', 'Pickup Point'],
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.newStudents.single.rollNo, '101');
      expect(preview.newStudents.single.institution, 'Green Valley');
      expect(preview.newStudents.single.boardingPoint, 'North Gate');
    });

    test('maps columns by name, not position', () {
      final preview = parse([
        ['NAME', 'STAGE', 'BORDING POINT', 'ROLL NO', 'INSTITUTION', 'BUS NO.'],
        ['Asha Rao', 'I', 'North Gate', '101', 'Green Valley', 'B-1'],
      ]);

      expect(preview.newStudents.single.rollNo, '101');
      expect(preview.newStudents.single.name, 'Asha Rao');
      expect(preview.newStudents.single.institution, 'Green Valley');
      expect(preview.newStudents.single.boardingPoint, 'North Gate');
    });

    test('finds a header that is not in the first row', () {
      final preview = parse([
        ['Bus Attendance Roster - Term 1'],
        _blankRow,
        ['Generated 2026-10-02'],
        _standardHeader,
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.headerRowNumber, 4);
      expect(preview.newStudents.single.rollNo, '101');
    });

    test('picks the sheet that actually has the columns', () {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Cover Page');
      excel['Cover Page'].appendRow([TextCellValue('Bus Attendance Roster')]);
      excel['Cover Page'].appendRow([TextCellValue('Term 1')]);

      excel['Roster'];
      final sheet = excel['Roster'];
      sheet.appendRow(_standardHeader.map(TextCellValue.new).toList());
      sheet.appendRow([
        TextCellValue('1'),
        TextCellValue('B-1'),
        TextCellValue('101'),
        TextCellValue('Asha Rao'),
        TextCellValue('Green Valley'),
        TextCellValue('I'),
        TextCellValue('North Gate'),
      ]);

      final bytes = excel.encode()!;
      final preview = service.parse(
        Uint8List.fromList(bytes),
        fileName: 'roster.xlsx',
        existingRollNos: const {},
      );

      expect(preview.sheetName, 'Roster');
      expect(preview.newStudents.single.rollNo, '101');
    });

    test('throws a helpful error when required columns are missing', () {
      expect(
        () => parse([
          ['S.NO.', 'BUS NO.', 'STAGE', 'REMARKS'],
          ['1', 'B-1', 'I', 'on time'],
        ]),
        throwsA(
          isA<ExcelImportException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Roll No'),
              contains('Boarding Point'),
              contains('Found:'),
            ),
          ),
        ),
      );
    });
  });

  group('row parsing', () {
    test('skips fully empty rows instead of reporting them invalid', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        _blankRow,
        ['', '', '', '', '', '', ''],
        ['2', 'B-1', '102', 'Bilal Khan', 'Green Valley', 'I', 'South Gate'],
        _blankRow,
      ]);

      expect(preview.skippedEmptyRows, 3);
      expect(preview.totalDataRows, 2);
      expect(preview.invalid, isEmpty);
      expect(preview.newStudents, hasLength(2));
    });

    test('reports blank cells as invalid with the field name', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        ['2', 'B-1', '102', '', 'Green Valley', 'I', 'South Gate'],
      ]);

      expect(preview.invalid, hasLength(2));
      expect(preview.invalid[0].rowNumber, 2);
      expect(preview.invalid[0].reason, contains('Roll No is missing'));
      expect(preview.invalid[0].name, 'Asha Rao');
      expect(preview.invalid[1].reason, contains('Name is missing'));
    });

    test('collapses messy whitespace inside values', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '  101  ', '  Asha   Rao ', 'Green   Valley', 'I', 'North Gate'],
      ]);

      final student = preview.newStudents.single;
      expect(student.rollNo, '101');
      expect(student.name, 'Asha Rao');
      expect(student.institution, 'Green Valley');
    });

    test('upper-cases roll numbers so they match the identity key', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', 'ab-12', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.newStudents.single.rollNo, 'AB-12');
    });

    test('turns a numeric roll number into text without a decimal tail', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        'ROLL NO',
        'NAME',
        'INSTITUTION',
        'BORDING POINT',
      ].map(TextCellValue.new).toList());
      sheet.appendRow([
        IntCellValue(101),
        TextCellValue('Asha Rao'),
        TextCellValue('Green Valley'),
        TextCellValue('North Gate'),
      ]);
      sheet.appendRow([
        DoubleCellValue(102.0),
        TextCellValue('Bilal Khan'),
        TextCellValue('Green Valley'),
        TextCellValue('South Gate'),
      ]);

      final preview = service.parse(
        Uint8List.fromList(excel.encode()!),
        fileName: 'roster.xlsx',
        existingRollNos: const {},
      );

      expect(
        preview.newStudents.map((s) => s.rollNo),
        ['101', '102'],
      );
    });

    test('treats a formula cell with no usable result as blank', () {
      // Real Excel files cache a formula's last computed value and the reader
      // prefers that, but a workbook written by a generator may not carry one.
      // Falling back to blank is deliberate: importing the formula text itself
      // as a roll number would be worse than reporting a missing value.
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        'ROLL NO',
        'NAME',
        'INSTITUTION',
        'BORDING POINT',
      ].map(TextCellValue.new).toList());
      sheet.appendRow([
        FormulaCellValue('UPPER(A1)'),
        TextCellValue('Asha Rao'),
        TextCellValue('Green Valley'),
        TextCellValue('North Gate'),
      ]);

      final preview = service.parse(
        Uint8List.fromList(excel.encode()!),
        fileName: 'roster.xlsx',
        existingRollNos: const {},
      );

      expect(preview.newStudents, isEmpty);
      expect(preview.invalid, hasLength(1));
      expect(preview.invalid.single.reason, contains('Roll No is missing'));
    });

    test('rejects over-long values instead of truncating them', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', 'R' * 51, 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        ['2', 'B-1', '102', 'N' * 101, 'Green Valley', 'I', 'South Gate'],
      ]);

      expect(preview.newStudents, isEmpty);
      expect(preview.invalid, hasLength(2));
      expect(preview.invalid[0].reason, contains('Roll No is too long (max 50)'));
      expect(preview.invalid[1].reason, contains('Name is too long (max 100)'));
    });
  });

  group('duplicate and existing detection', () {
    test('flags repeated roll numbers and keeps the first occurrence', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        ['2', 'B-1', '102', 'Bilal Khan', 'Green Valley', 'I', 'South Gate'],
        ['3', 'B-1', '101', 'Asha R. Rao', 'Green Valley', 'I', 'West Gate'],
      ]);

      expect(preview.newStudents.map((s) => s.rollNo), ['101', '102']);
      expect(preview.duplicates, hasLength(1));
      expect(preview.duplicates.single.rowNumber, 4);
      expect(preview.duplicates.single.firstRowNumber, 2);
      expect(preview.duplicates.single.rollNo, '101');
    });

    test('treats case and spacing differences as the same roll number', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', 'ab-12', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        ['2', 'B-1', ' AB-12 ', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.newStudents, hasLength(1));
      expect(preview.duplicates, hasLength(1));
      expect(preview.duplicates.single.rollNo, 'AB-12');
    });

    test('reports students already in the database as existing, not new', () {
      final preview = parse(
        [
          _standardHeader,
          ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
          ['2', 'B-1', '102', 'Bilal Khan', 'Green Valley', 'I', 'South Gate'],
        ],
        existing: {'101'},
      );

      expect(preview.newStudents.map((s) => s.rollNo), ['102']);
      expect(preview.existing, hasLength(1));
      expect(preview.existing.single.rollNo, '101');
      expect(preview.existing.single.rowNumber, 2);
      expect(preview.skippedCount, 1);
    });

    test('does not touch the existing roll number set while parsing', () {
      final existing = <String>{'101'};
      parse(
        [
          _standardHeader,
          ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
          ['2', 'B-1', '999', 'Bilal Khan', 'Green Valley', 'I', 'South Gate'],
        ],
        existing: existing,
      );

      expect(existing, {'101'});
    });

    test('an invalid row does not block a later valid row with the same roll no', () {
      final preview = parse([
        _standardHeader,
        ['1', 'B-1', '101', '', 'Green Valley', 'I', 'North Gate'],
        ['2', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
      ]);

      expect(preview.invalid, hasLength(1));
      expect(preview.duplicates, isEmpty);
      expect(preview.newStudents.single.name, 'Asha Rao');
    });

    test('canImport is false when there is nothing new to add', () {
      final preview = parse(
        [
          _standardHeader,
          ['1', 'B-1', '101', 'Asha Rao', 'Green Valley', 'I', 'North Gate'],
        ],
        existing: {'101'},
      );

      expect(preview.canImport, isFalse);
    });
  });

  group('file guards', () {
    test('rejects a file that is not a spreadsheet', () {
      expect(
        () => service.parse(
          Uint8List.fromList([1, 2, 3, 4]),
          fileName: 'notes.txt',
          existingRollNos: const {},
        ),
        throwsA(
          isA<ExcelImportException>().having(
            (e) => e.message,
            'message',
            contains('not a spreadsheet'),
          ),
        ),
      );
    });

    test('rejects an empty file', () {
      expect(
        () => service.parse(
          Uint8List(0),
          fileName: 'empty.xlsx',
          existingRollNos: const {},
        ),
        throwsA(isA<ExcelImportException>()),
      );
    });

    test('reports a corrupt workbook rather than crashing', () {
      expect(
        () => service.parse(
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]),
          fileName: 'broken.xlsx',
          existingRollNos: const {},
        ),
        throwsA(isA<ExcelImportException>()),
      );
    });
  });

  group('normalisation helpers', () {
    test('normaliseHeader strips punctuation and case', () {
      expect(ExcelImportService.normaliseHeader(' ROLL NO. '), 'rollno');
      expect(ExcelImportService.normaliseHeader('Roll-No'), 'rollno');
      expect(ExcelImportService.normaliseHeader('ROLL_NO'), 'rollno');
      expect(ExcelImportService.normaliseHeader('S.NO.'), 'sno');
    });

    test('normaliseValue collapses whitespace including zero-width spaces', () {
      expect(ExcelImportService.normaliseValue('  Asha \t\n Rao  '), 'Asha Rao');
      expect(ExcelImportService.normaliseValue('Asha Rao'), 'Asha Rao');
    });
  });
}
