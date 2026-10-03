import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../attendance/models/attendance_models.dart';
import '../history_controller.dart';

/// Attendance History list.
///
/// One row per stored session, newest first, with the day's totals and a link
/// to the frozen roster for that session.
class AttendanceHistoryPage extends ConsumerWidget {
  const AttendanceHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(attendanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load history.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('No attendance sessions yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(attendanceHistoryProvider),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Present')),
                    DataColumn(label: Text('Absent')),
                    DataColumn(label: Text('%')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final session in sessions)
                      DataRow(
                        cells: [
                          DataCell(Text(_formatDate(session.attendanceDate))),
                          DataCell(Text('${session.total}')),
                          DataCell(Text('${session.present}')),
                          DataCell(Text('${session.absent}')),
                          DataCell(
                            Text('${session.percent.toStringAsFixed(0)}%'),
                          ),
                          DataCell(_StatusChip(status: session.status)),
                          DataCell(
                            TextButton.icon(
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('View'),
                              onPressed: () =>
                                  context.push('/history/${session.sessionId}'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AttendanceSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == AttendanceSessionStatus.open;
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(isOpen ? 'Open' : 'Completed'),
      visualDensity: VisualDensity.compact,
      backgroundColor: isOpen
          ? scheme.tertiaryContainer
          : scheme.secondaryContainer,
    );
  }
}
