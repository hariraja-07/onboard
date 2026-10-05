import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/spacing.dart';
import '../../attendance/models/attendance_models.dart';
import '../history_controller.dart';
import '../widgets/delete_session_dialog.dart';

/// Frozen roster for one attendance session.
///
/// Every field comes from the snapshot taken when the session started, so names,
/// institutions and boarding points read as they were on the day, regardless of
/// later edits to the student record.
class AttendanceSessionDetailsPage extends ConsumerStatefulWidget {
  const AttendanceSessionDetailsPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<AttendanceSessionDetailsPage> createState() =>
      _AttendanceSessionDetailsPageState();
}

class _AttendanceSessionDetailsPageState
    extends ConsumerState<AttendanceSessionDetailsPage> {
  final TextEditingController _search = TextEditingController();
  AttendanceFilter _status = AttendanceFilter.all;
  String? _institution;
  String? _boardingPoint;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Deletes the session on screen and leaves it, since there is nothing left
  /// here to show once it is gone.
  Future<void> _deleteSession(
    BuildContext context,
    WidgetRef ref,
    AttendanceSessionDetails details,
  ) async {
    final deleted = await confirmDeleteSession(context, ref, details.summary);
    if (deleted && context.mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(sessionDetailsProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          // Only offered once the summary is known, because the confirmation
          // names the date and trip and counts the records.
          if (details.hasValue)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete session',
              onPressed: () =>
                  _deleteSession(context, ref, details.requireValue),
            ),
        ],
      ),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: Insets.allLg,
            child: Text(
              'Could not load the session.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) => _DetailsBody(
          details: data,
          search: _search,
          status: _status,
          institution: _institution,
          boardingPoint: _boardingPoint,
          onStatusChanged: (value) => setState(() => _status = value),
          onInstitutionChanged: (value) => setState(() => _institution = value),
          onBoardingPointChanged: (value) =>
              setState(() => _boardingPoint = value),
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.details,
    required this.search,
    required this.status,
    required this.institution,
    required this.boardingPoint,
    required this.onStatusChanged,
    required this.onInstitutionChanged,
    required this.onBoardingPointChanged,
  });

  final AttendanceSessionDetails details;
  final TextEditingController search;
  final AttendanceFilter status;
  final String? institution;
  final String? boardingPoint;
  final ValueChanged<AttendanceFilter> onStatusChanged;
  final ValueChanged<String?> onInstitutionChanged;
  final ValueChanged<String?> onBoardingPointChanged;

  @override
  Widget build(BuildContext context) {
    final filters = AttendanceHistoryFilters(
      query: search.text,
      status: status,
      institution: institution,
      boardingPoint: boardingPoint,
    );
    final entries = details.filtered(filters);
    final summary = details.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.xs,
          ),
          child: Row(
            children: [
              Text(
                formatHistoryDate(summary.attendanceDate),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: Insets.sm),
              Chip(
                avatar: Icon(
                  summary.tripType == TripType.morning
                      ? Icons.wb_sunny_outlined
                      : Icons.nights_stay_outlined,
                  size: 14,
                ),
                label: Text(summary.tripType.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: Insets.horizontalMd,
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Stat(label: 'Total', value: '${summary.total}'),
              _Stat(label: 'Present', value: '${summary.present}'),
              _Stat(label: 'Absent', value: '${summary.absent}'),
              _Stat(
                label: 'Percentage',
                value: '${summary.percent.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xs),
        Padding(
          padding: Insets.horizontalMd,
          child: SegmentedButton<AttendanceFilter>(
            segments: const [
              ButtonSegment(value: AttendanceFilter.all, label: Text('All')),
              ButtonSegment(
                value: AttendanceFilter.present,
                label: Text('Present'),
              ),
              ButtonSegment(
                value: AttendanceFilter.absent,
                label: Text('Absent'),
              ),
            ],
            selected: {status},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onStatusChanged(s.first);
            },
          ),
        ),
        const SizedBox(height: Insets.xs),
        Padding(
          padding: Insets.horizontalMd,
          child: TextField(
            controller: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search roll no or name',
            ),
          ),
        ),
        const SizedBox(height: Insets.xs),
        Padding(
          padding: Insets.horizontalMd,
          child: Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  hint: 'Institution',
                  value: institution,
                  options: details.institutions,
                  onChanged: onInstitutionChanged,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _FilterDropdown(
                  hint: 'Boarding Point',
                  value: boardingPoint,
                  options: details.boardingPoints,
                  onChanged: onBoardingPointChanged,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No students match these filters.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isPresent = entry.status == AttendanceStatus.present;
                    final theme = Theme.of(context);
                    final avatarLetter = entry.name.isNotEmpty
                        ? entry.name[0].toUpperCase()
                        : (entry.rollNo.isNotEmpty
                              ? entry.rollNo[0].toUpperCase()
                              : '?');

                    return Card(
                      margin: const EdgeInsets.only(bottom: Insets.xs),
                      elevation: 0,
                      color: isPresent
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            )
                          : theme.colorScheme.surfaceContainer,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: isPresent
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          child: Text(avatarLetter),
                        ),
                        title: Text(
                          entry.name.isNotEmpty ? entry.name : entry.rollNo,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('${entry.rollNo} • ${entry.boardingPoint}'),
                            if (entry.institution.isNotEmpty)
                              Text(
                                entry.institution,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusLabel(status: entry.status),
                            if (isPresent && entry.scannedAt != null) ...[
                              const SizedBox(height: Insets.xxs),
                              Text(
                                _formatTime(entry.scannedAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '—';
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final present = status == AttendanceStatus.present;
    return Text(
      present ? 'Present' : 'Absent',
      style: TextStyle(
        color: present
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: hint),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        for (final option in options)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}
