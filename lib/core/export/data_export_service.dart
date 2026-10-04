import 'package:excel_community/excel_community.dart';

import '../database/database.dart';

/// Builds a human-readable Excel workbook of all OnBoard data.
///
/// This is the "Export data" companion to a `.onboard` backup: a backup is for
/// restoring OnBoard exactly, whereas this workbook is for opening in Excel or
/// Sheets. It is read-only and lossy about ids only in the sense that it adds
/// date columns for readability.
class DataExportService {
  DataExportService(this.db);

  final AppDatabase db;

  static const String studentsSheet = 'Students';
  static const String sessionsSheet = 'Attendance Sessions';
  static const String recordsSheet = 'Attendance Records';

  static const List<String> _studentHeaders = [
    'ID',
    'Roll No',
    'Name',
    'Institution',
    'Boarding Point',
    'Created At',
    'Updated At',
  ];

  static const List<String> _sessionHeaders = [
    'ID',
    'Date',
    'Trip',
    'Status',
    'Started At',
    'Ended At',
  ];

  static const List<String> _recordHeaders = [
    'ID',
    'Session ID',
    'Date',
    'Roll No',
    'Name',
    'Institution',
    'Boarding Point',
    'Status',
    'Scanned Barcode',
    'Scanned At',
  ];

  static const String _brandPrimaryHex = '1A73E8';

  /// A timestamped filename so repeated exports don't overwrite each other.
  static String fileNameFor(DateTime now) =>
      'onboard_data_export_${formatTimestamp(now)}.xlsx';

  /// Loads all rows and encodes the workbook, ready to hand to a save dialog.
  Future<List<int>?> build() async {
    final students = await db.select(db.students).get();
    final sessions = await db.select(db.attendanceSessions).get();
    final records = await db.select(db.attendanceRecords).get();

    final sessionDates = {
      for (final session in sessions) session.id: session.attendanceDate,
    };

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _writeSheet(excel, studentsSheet, _studentHeaders, [
      for (final s in students)
        [
          '${s.id}',
          s.rollNo,
          s.name,
          s.institution,
          s.boardingPoint,
          formatDateTime(s.createdAt),
          s.updatedAt == null ? '' : formatDateTime(s.updatedAt!),
        ],
    ]);

    _writeSheet(excel, sessionsSheet, _sessionHeaders, [
      for (final s in sessions)
        [
          '${s.id}',
          formatDate(s.attendanceDate),
          s.tripType == 'evening' ? 'Evening' : 'Morning',
          s.status,
          formatDateTime(s.createdAt),
          s.endedAt == null ? '' : formatDateTime(s.endedAt!),
        ],
    ]);

    _writeSheet(excel, recordsSheet, _recordHeaders, [
      for (final r in records)
        [
          '${r.id}',
          '${r.sessionId}',
          formatDate(sessionDates[r.sessionId] ?? r.scannedAt),
          r.rollNoSnapshot,
          r.nameSnapshot,
          r.institutionSnapshot,
          r.boardingPointSnapshot,
          r.status,
          r.scannedBarcode,
          formatDateTime(r.scannedAt),
        ],
    ]);

    excel.setDefaultSheet(studentsSheet);
    return excel.encode();
  }

  void _writeSheet(
    Excel excel,
    String name,
    List<String> headers,
    List<List<String>> rows,
  ) {
    final sheet = excel[name];
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

    final bodyStyle = CellStyle(verticalAlign: VerticalAlign.Center);
    for (var row = 0; row < rows.length; row++) {
      final values = rows[row];
      for (var column = 0; column < values.length; column++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row + 1),
          TextCellValue(values[column]),
          cellStyle: bodyStyle,
        );
      }
    }
  }
}

/// `YYYY-MM-DD`, matching the rest of the app (no `intl` dependency).
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// `YYYY-MM-DD HH:MM`.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// `YYYYMMDD_HHMMSS`, used in export filenames.
String formatTimestamp(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}'
      '${local.second.toString().padLeft(2, '0')}';
}
