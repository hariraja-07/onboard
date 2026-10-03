import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/features/students/import/excel_import_models.dart';
import 'package:onboard/features/students/import/excel_import_service.dart';
import 'package:onboard/features/students/import/excel_template_service.dart';

void main() {
  const template = ExcelTemplateService();

  test('builds a workbook the reader can parse back', () {
    final bytes = template.build();
    expect(bytes, isNotNull);
    expect(bytes, isNotEmpty);

    final excel = Excel.decodeBytes(bytes!);
    expect(excel.tables.keys, contains(ExcelTemplateService.sheetName));
    expect(excel.getDefaultSheet(), ExcelTemplateService.sheetName);
  });

  test('carries the full roster header, including the ignored columns', () {
    final excel = Excel.decodeBytes(template.build()!);
    final sheet = excel[ExcelTemplateService.sheetName];

    final header = sheet.rows.first
        .map((cell) => cell?.value.toString() ?? '')
        .toList();

    expect(header, ExcelTemplateService.headers);
    expect(header, contains('S.NO.'));
    expect(header, contains('BUS NO.'));
    expect(header, contains('STAGE'));
  });

  test('a filled-in copy of the template imports cleanly', () {
    final preview = ExcelImportService().parse(
      Uint8List.fromList(template.build()!),
      fileName: ExcelTemplateService.fileName,
      existingRollNos: const {},
    );

    expect(
      preview.newStudents,
      hasLength(ExcelTemplateService.sampleRows.length),
    );
    expect(preview.invalid, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(preview.existing, isEmpty);

    for (final field in ImportField.values) {
      expect(preview.detectedColumns[field], isNotNull);
    }

    final first = preview.newStudents.first;
    expect(first.rollNo, '2026001');
    expect(first.name, 'Asha Rao');
    expect(first.institution, 'Green Valley School');
    expect(first.boardingPoint, 'North Gate');
  });

  test('freezes the header row', () {
    final excel = Excel.decodeBytes(template.build()!);
    expect(excel[ExcelTemplateService.sheetName].frozenRows, 1);
  });
}
