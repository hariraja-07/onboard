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
tooltip: 'Export all sessions in these filters',
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
                  ? _EmptyView(range: range)
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

/// A date row and a trip row, which combine.
///
/// The two axes are separate because Morning and Evening are separate
/// sessions on the same day, so "the last 30 days of evening trips" is a real
/// question that a single list of mutually exclusive presets cannot answer.
class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final presets = _datePresets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final preset in presets)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: _DateChip(
                    label: preset.label,
                    range: preset.range,
                    selected: _sameDates(range, preset.range),
                    onSelected: () =>
                        ref.read(reportRangeProvider.notifier).state = range
                            .withDates(
                              from: preset.range.from,
                              to: preset.range.to,
                            ),
                    onPick: () => _pickSpecificDate(context, ref, range),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Text(
                'Trip',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const <(String, TripType?)>[
                      ('All trips', null),
                      ('Morning', TripType.morning),
                      ('Evening', TripType.evening),
                    ])
                      ChoiceChip(
                        label: Text(option.$1),
                        selected: range.trip == option.$2,
                        onSelected: (_) =>
                            ref.read(reportRangeProvider.notifier).state =
                                range.withTrip(option.$2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Today, the previous calendar week and a rolling 30 days.
  List<_DatePreset> _datePresets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return [
      _DatePreset('All', const ReportRange()),
      _DatePreset('Today', ReportRange(from: today, to: today)),
      _DatePreset(
        'Last week',
        ReportRange(
          from: weekStart.subtract(const Duration(days: 7)),
          to: weekStart.subtract(const Duration(days: 1)),
        ),
      ),
      _DatePreset(
        'Last 30 days',
        ReportRange(
          from: today.subtract(const Duration(days: 29)),
          to: today,
        ),
      ),
      _DatePreset(
        '📅',
        ReportRange(),
        isDatePicker: true,
      ),
    ];
  }

  /// Compares dates alone, so a trip chip does not unhighlight a date chip.
  static bool _sameDates(ReportRange a, ReportRange b) =>
      a.from == b.from && a.to == b.to;

  Future<void> _pickSpecificDate(
    BuildContext context,
    WidgetRef ref,
    ReportRange current,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDate: current.from,
    );
    if (picked == null) return;
    ref.read(reportRangeProvider.notifier).state = current.withDates(
      from: DateTime(picked.year, picked.month, picked.day),
      to: DateTime(picked.year, picked.month, picked.day),
    );
  }
}

class _DatePreset {
  const _DatePreset(this.label, this.range, {this.isDatePicker = false});

  final String label;
  final ReportRange range;
  final bool isDatePicker;
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.range,
    required this.selected,
    required this.onSelected,
    required this.onPick,
  });

  final String label;
  final ReportRange range;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (range.from == null && range.to == null && label.startsWith('📅')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ActionChip(
          avatar: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(label),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          onPressed: onPick,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ReportBody extends ConsumerStatefulWidget {
  const _ReportBody({required this.bundle});

  final ReportBundle bundle;

  @override
  ConsumerState<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends ConsumerState<_ReportBody> {
  /// Which session is currently being written out.
  ///
  /// Keyed per session rather than a single busy flag, so exporting one
  /// session does not disable every other row's button.
  int? _exportingSessionId;

  @override
  Widget build(BuildContext context) {
    final report = widget.bundle.report;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SectionHeader('Sessions (${report.sessionCount})'),
        for (final session in report.sessions)
          _SessionTile(
            session: session,
            exporting: _exportingSessionId == session.sessionId,
            onExport: () => _exportSession(session),
          ),
      ],
    );
  }

  Future<void> _exportSession(AttendanceSessionSummary session) async {
    setState(() => _exportingSessionId = session.sessionId);
    final service = ref.read(reportServiceProvider);
    final gateway = ref.read(backupFileGatewayProvider);
    try {
      final bytes = Uint8List.fromList(
        await service.buildSessionExcel(session),
      );
      final location = await gateway.saveExport(
        bytes,
        ReportService.sessionFileName(session),
      );
      _notify(
        location == null
            ? 'Export cancelled.'
            : 'Saved ${formatDate(session.attendanceDate)} '
                  '${session.tripType.label} to $location',
      );
    } catch (error) {
      _notify('Could not export: $error');
    } finally {
      if (mounted) setState(() => _exportingSessionId = null);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.exporting,
    required this.onExport,
  });

  final AttendanceSessionSummary session;
  final bool exporting;
  final VoidCallback onExport;

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
                '${session.percent.toStringAsFixed(1)}% · '
                '${open ? 'Open' : 'Completed'}',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: session.total == 0 ? 0 : session.present / session.total,
              ),
            ],
          ),
        ),
        // A single target, and it is not the row: the row opens the session,
        // so an export tap has to be unambiguous.
        trailing: IconButton(
          icon: exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          tooltip: 'Export this session',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: exporting ? null : onExport,
        ),
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
  const _EmptyView({required this.range});

  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('No sessions match these filters'),
            const SizedBox(height: 4),
            Text(
              // Naming the filter that came up empty, since the most likely
              // cause is a trip chip narrowing a range that had sessions.
              'Nothing recorded for ${range.label}.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SkeletonBox(width: 120, height: 20),
        const SizedBox(height: 12),
        const SkeletonBox(width: double.infinity, height: 76, radius: 12),
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 76, radius: 12),
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 76, radius: 12),
      ],
    );
  }
}

