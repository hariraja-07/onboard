import 'package:drift/drift.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/attendance_session_repository.dart';
import '../../core/export/data_export_service.dart';
import '../attendance/models/attendance_models.dart';

/// One student who was on a session's snapshot roster but has no record.
class ReportAbsence {
  const ReportAbsence({
    required this.sessionId,
    required this.attendanceDate,
    required this.rollNo,
    required this.name,
    required this.boardingPoint,
  });

  final int sessionId;
  final DateTime attendanceDate;
  final String rollNo;
  final String name;
  final String boardingPoint;
}

/// Aggregated attendance across the sessions in a date range.
class AttendanceReport {
  const AttendanceReport({required this.sessions, this.from, this.to});

  final List<AttendanceSessionSummary> sessions;
  final DateTime? from;
  final DateTime? to;

  int get sessionCount => sessions.length;
  int get totalExpected => sessions.fold(0, (sum, s) => sum + s.total);
  int get totalPresent => sessions.fold(0, (sum, s) => sum + s.present);
  int get totalAbsent => sessions.fold(0, (sum, s) => sum + s.absent);

  double get overallPercent =>
      totalExpected == 0 ? 0 : totalPresent * 100.0 / totalExpected;

  bool get isEmpty => sessions.isEmpty;
}

/// Everything the Reports screen renders for one range.
class ReportBundle {
  const ReportBundle({required this.report, required this.absences});

  final AttendanceReport report;
  final List<ReportAbsence> absences;
}

/// The half-open date range a report is built for. Null bounds mean "no limit".
class ReportRange {
  const ReportRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  String get label {
    if (from == null && to == null) return 'All time';
    String date(DateTime d) => formatDate(d);
    if (from != null && to != null) return '${date(from!)} – ${date(to!)}';
    if (from != null) return 'From ${date(from!)}';
    return 'Until ${date(to!)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(ref.watch(databaseProvider));
});

final reportRangeProvider = StateProvider<ReportRange>(
  (ref) => const ReportRange(),
);

/// Builds the summary rows and the absentee list for [range].
final attendanceReportProvider = FutureProvider.autoDispose
    .family<ReportBundle, ReportRange>((ref, range) {
      final service = ref.watch(reportServiceProvider);
      return service.buildBundle(from: range.from, to: range.to);
    });

/// Reads attendance data and renders it as a report.
class ReportService {
  ReportService(this.db);

  final AppDatabase db;

  static const String summarySheet = 'Summary';
  static const String sessionsSheet = 'Sessions';
  static const String absencesSheet = 'Absences';

  static const String _brandPrimaryHex = '1A73E8';

  /// A timestamped filename so repeated exports don't overwrite each other.
  static String excelFileName(DateTime now) =>
      'onboard_report_${formatTimestamp(now)}.xlsx';

  static String csvFileName(DateTime now) =>
      'onboard_report_${formatTimestamp(now)}.csv';

  Future<ReportBundle> buildBundle({DateTime? from, DateTime? to}) async {
    final report = await build(from: from, to: to);
    final absences = await absentees(from: from, to: to);
    return ReportBundle(report: report, absences: absences);
  }

  Future<AttendanceReport> build({DateTime? from, DateTime? to}) async {
    final sessions = await AttendanceSessionRepository(
      db,
    ).listSessions(from: from, to: to, limit: null);
    return AttendanceReport(sessions: sessions, from: from, to: to);
  }

  /// Students on a session's frozen roster who were never marked present.
  ///
  /// Uses the snapshot roster rather than the live student table, so a report
  /// reflects who was actually expected on the day.
  Future<List<ReportAbsence>> absentees({DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final variables = <Variable>[];
    if (from != null) {
      where.add('s.attendance_date >= ?');
      variables.add(
        Variable.withDateTime(DateTime(from.year, from.month, from.day)),
      );
    }
    if (to != null) {
      where.add('s.attendance_date < ?');
      variables.add(
        Variable.withDateTime(
          DateTime(to.year, to.month, to.day).add(const Duration(days: 1)),
        ),
      );
    }
    final whereClause = where.isEmpty ? '' : 'AND ${where.join(' AND ')}';

    final rows = await db.customSelect('''
SELECT r.session_id, s.attendance_date, r.roll_no, r.name, r.boarding_point
FROM attendance_session_roster r
JOIN attendance_sessions s ON s.id = r.session_id
LEFT JOIN attendance_records ar
  ON ar.session_id = r.session_id AND ar.student_id = r.student_id
WHERE ar.id IS NULL
$whereClause
ORDER BY s.attendance_date DESC, r.roll_no ASC
''', variables: variables).get();

    return [
      for (final row in rows)
        ReportAbsence(
          sessionId: row.read<int>('session_id'),
          attendanceDate: row.read<DateTime>('attendance_date'),
          rollNo: row.read<String>('roll_no'),
          name: row.read<String>('name'),
          boardingPoint: row.read<String>('boarding_point'),
        ),
    ];
  }

  /// A three-sheet workbook: Summary, per-session Sessions, and Absences.
  List<int> buildExcel(ReportBundle bundle) {
    final report = bundle.report;
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _writeSheet(
      excel,
      summarySheet,
      const ['Metric', 'Value'],
      [
        ['From', report.from == null ? 'All time' : formatDate(report.from!)],
        ['To', report.to == null ? 'All time' : formatDate(report.to!)],
        ['Sessions', '${report.sessionCount}'],
        ['Expected', '${report.totalExpected}'],
        ['Present', '${report.totalPresent}'],
        ['Absent', '${report.totalAbsent}'],
        ['Attendance %', report.overallPercent.toStringAsFixed(1)],
      ],
    );

    _writeSheet(
      excel,
      sessionsSheet,
      const ['Date', 'Session ID', 'Status', 'Total', 'Present', 'Absent', '%'],
      [
        for (final s in report.sessions)
          [
            formatDate(s.attendanceDate),
            '${s.sessionId}',
            s.status == AttendanceSessionStatus.completed
                ? 'Completed'
                : 'Open',
            '${s.total}',
            '${s.present}',
            '${s.absent}',
            s.percent.toStringAsFixed(1),
          ],
      ],
    );

    _writeSheet(
      excel,
      absencesSheet,
      const ['Date', 'Session ID', 'Roll No', 'Name', 'Boarding Point'],
      [
        for (final a in bundle.absences)
          [
            formatDate(a.attendanceDate),
            '${a.sessionId}',
            a.rollNo,
            a.name,
            a.boardingPoint,
          ],
      ],
    );

    excel.setDefaultSheet(summarySheet);
    return excel.encode() ?? const <int>[];
  }

  /// A single CSV containing the summary, the per-session rows and absences.
  String buildCsv(ReportBundle bundle) {
    final report = bundle.report;
    final lines = <List<String>>[
      ['OnBoard Attendance Report'],
      ['From', report.from == null ? 'All time' : formatDate(report.from!)],
      ['To', report.to == null ? 'All time' : formatDate(report.to!)],
      [],
      ['Summary'],
      ['Sessions', '${report.sessionCount}'],
      ['Expected', '${report.totalExpected}'],
      ['Present', '${report.totalPresent}'],
      ['Absent', '${report.totalAbsent}'],
      ['Attendance %', report.overallPercent.toStringAsFixed(1)],
      [],
      ['Sessions'],
      ['Date', 'Session ID', 'Status', 'Total', 'Present', 'Absent', '%'],
      for (final s in report.sessions)
        [
          formatDate(s.attendanceDate),
          '${s.sessionId}',
          s.status == AttendanceSessionStatus.completed ? 'Completed' : 'Open',
          '${s.total}',
          '${s.present}',
          '${s.absent}',
          s.percent.toStringAsFixed(1),
        ],
      [],
      ['Absences'],
      ['Date', 'Session ID', 'Roll No', 'Name', 'Boarding Point'],
      for (final a in bundle.absences)
        [
          formatDate(a.attendanceDate),
          '${a.sessionId}',
          a.rollNo,
          a.name,
          a.boardingPoint,
        ],
    ];
    return lines.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
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
