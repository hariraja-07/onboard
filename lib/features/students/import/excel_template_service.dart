import 'package:excel_community/excel_community.dart';

/// Builds the blank roster template users can download from the import screen.
///
/// The template deliberately mirrors the layout bus operators already export,
/// including the columns OnBoard ignores, so filling it in looks like editing
/// their existing sheet rather than learning a new one.
class ExcelTemplateService {
  const ExcelTemplateService();

  static const String sheetName = 'Students';
  static const String fileName = 'onboard_students_template.xlsx';

  /// The full header, in the order OnBoard expects. Only Roll No, Name,
  /// Institution and Boarding Point are imported; the rest are carried through
  /// so the sheet still reads like a bus roster.
  static const List<String> headers = [
    'S.NO.',
    'BUS NO.',
    'ROLL NO',
    'NAME',
    'INSTITUTION',
    'STAGE',
    'BORDING POINT',
  ];

  /// Matches `AppTheme`'s primary colour so the template looks like the app.
  static const String _brandPrimaryHex = '1A73E8';

  /// Example rows showing the shape of each column.
  static const List<List<String>> sampleRows = [
    ['1', 'B-1', '2026001', 'Asha Rao', 'Green Valley School', 'I', 'North Gate'],
    ['2', 'B-1', '2026002', 'Bilal Khan', 'Green Valley School', 'I', 'South Gate'],
    ['3', 'B-2', '2026003', 'Chitra Menon', 'Riverside Public School', 'II', 'East Gate'],
  ];

  /// Encodes the template, ready to hand to a save dialog.
  ///
  /// Returns null only if the encoder produced nothing, which should not
  /// happen for a fixed, known-good workbook.
  List<int>? build() {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    excel[sheetName];

    final sheet = excel[sheetName];
    sheet.frozenRows = 1;

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(_brandPrimaryHex),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (var column = 0; column < headers.length; column++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
        TextCellValue(headers[column]),
        cellStyle: headerStyle,
      );
    }

    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Center,
    );

    for (var row = 0; row < sampleRows.length; row++) {
      final values = sampleRows[row];
      for (var column = 0; column < values.length; column++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row + 1),
          TextCellValue(values[column]),
          cellStyle: bodyStyle,
        );
      }
    }

    excel.setDefaultSheet(sheetName);
    return excel.encode();
  }
}
