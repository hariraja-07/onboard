import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/export/data_export_service.dart';
import '../../../core/widgets/skeleton.dart';
import '../../attendance/models/attendance_models.dart';
import '../../settings/settings_controller.dart';
import '../report_service.dart';

/// Attendance analytics over a date range, with Excel/CSV export.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportRangeProvider);
    final report = ref.watch(attendanceReportProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          report.maybeWhen(
            data: (bundle) => PopupMenuButton<_ExportKind>(
              enabled: !_exporting && !bundle.report.isEmpty,
              tooltip: 'Export report',
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              onSelected: (kind) => _export(kind, bundle),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ExportKind.excel,
                  child: ListTile(
                    leading: Icon(Icons.grid_on_outlined),
                    title: Text('Excel (.xlsx)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _ExportKind.csv,
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('CSV (.csv)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          const _RangeSelector(),
          const Divider(height: 1),
          Expanded(
            child: report.when(
              loading: () => const _ReportsSkeleton(),
              error: (error, _) => _ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(attendanceReportProvider(range)),
              ),
              data: (bundle) => bundle.report.isEmpty
                  ? const _EmptyView()
                  : _ReportBody(bundle: bundle),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(_ExportKind kind, ReportBundle bundle) async {
    setState(() => _exporting = true);
    final service = ref.read(reportServiceProvider);
    final gateway = ref.read(backupFileGatewayProvider);
    final now = DateTime.now();
    try {
      final Uint8List bytes;
      final String fileName;
      if (kind == _ExportKind.excel) {
        bytes = Uint8List.fromList(service.buildExcel(bundle));
        fileName = ReportService.excelFileName(now);
      } else {
        bytes = Uint8List.fromList(utf8.encode(service.buildCsv(bundle)));
        fileName = ReportService.csvFileName(now);
      }
      final location = await gateway.saveExport(bytes, fileName);
      _notify(location == null ? 'Export cancelled.' : 'Saved to $location');
    } catch (error) {
      _notify('Could not export: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ExportKind { excel, csv }

/// Quick presets plus a custom range picker.
class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <(String, ReportRange)>[
      ('All time', const ReportRange()),
      (
        'Last 7 days',
        ReportRange(from: today.subtract(const Duration(days: 6)), to: today),
      ),
      (
        'Last 30 days',
        ReportRange(from: today.subtract(const Duration(days: 29)), to: today),
      ),
    ];

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (label, preset) in presets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ChoiceChip(
                label: Text(label),
                selected: range == preset,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                onSelected: (_) =>
                    ref.read(reportRangeProvider.notifier).state = preset,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                presets.any((p) => p.$2 == range) ? 'Custom' : range.label,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              onPressed: () => _pickCustomRange(context, ref, range),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    ReportRange current,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current.from != null && current.to != null
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
    );
    if (picked == null) return;
    ref.read(reportRangeProvider.notifier).state = ReportRange(
      from: picked.start,
      to: picked.end,
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.bundle});

  final ReportBundle bundle;

  @override
  Widget build(BuildContext context) {
    final report = bundle.report;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryCards(report: report),
        const SizedBox(height: 24),
        _SectionHeader('Sessions (${report.sessionCount})'),
        for (final session in report.sessions) _SessionTile(session: session),
        const SizedBox(height: 24),
        _SectionHeader('Absences (${bundle.absences.length})'),
        if (bundle.absences.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Everyone was present.'),
          )
        else
          for (final absence in bundle.absences) _AbsenceTile(absence: absence),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Sessions',
                value: '${report.sessionCount}',
                icon: Icons.event_note_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Present',
                value: '${report.totalPresent}/${report.totalExpected}',
                icon: Icons.how_to_reg_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Absent',
                value: '${report.totalAbsent}',
                icon: Icons.person_off_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Attendance',
                value: '${report.overallPercent.toStringAsFixed(1)}%',
                icon: Icons.percent_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final AttendanceSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = session.status == AttendanceSessionStatus.open;
    final isMorning = session.tripType == TripType.morning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/history/${session.sessionId}'),
        leading: Icon(
          isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          '${formatDate(session.attendanceDate)} · ${session.tripType.label}',
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.present}/${session.total} present · '
                '${session.percent.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: session.total == 0 ? 0 : session.present / session.total,
              ),
            ],
          ),
        ),
        trailing: Chip(
          label: Text(open ? 'Open' : 'Completed'),
          backgroundColor: open
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          side: BorderSide.none,
        ),
      ),
    );
  }
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({required this.absence});

  final ReportAbsence absence;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_off_outlined),
      title: Text('${absence.rollNo} · ${absence.name}'),
      subtitle: Text(
        '${formatDate(absence.attendanceDate)} · ${absence.tripType.label} · ${absence.boardingPoint}',
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No attendance in this range'),
          const SizedBox(height: 4),
          Text(
            'Take attendance and it will show up here.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not build report.\n$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Row(
          children: [
            Expanded(child: SkeletonBox(width: double.infinity, height: 96, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(width: double.infinity, height: 96, radius: 16)),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: SkeletonBox(width: double.infinity, height: 96, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(width: double.infinity, height: 96, radius: 16)),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonBox(width: 120, height: 20),
        const SizedBox(height: 12),
        const SkeletonBox(width: double.infinity, height: 76, radius: 12),
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 76, radius: 12),
      ],
    );
  }
}

