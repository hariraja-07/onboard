import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/spacing.dart';
import '../../attendance/models/attendance_models.dart';
import '../history_controller.dart';
import '../widgets/delete_session_dialog.dart';

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
            padding: Insets.allLg,
            child: Text(
              'Could not load history.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: Insets.allLg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'No attendance sessions yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    const Text('Past completed sessions will appear here.'),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(attendanceHistoryProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionCard(
                  session: session,
                  onDelete: () => confirmDeleteSession(context, ref, session),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onDelete});

  final AttendanceSessionSummary session;

  /// Runs the confirmed delete. Passed in rather than read from a provider so
  /// the card stays a plain widget and this widget stays the only place that
  /// knows about dialogs and snackbars.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMorning = session.tripType == TripType.morning;
    final ratio = session.total == 0 ? 0.0 : session.present / session.total;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${session.sessionId}'),
        child: Padding(
          padding: Insets.allMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isMorning
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      '${formatHistoryDate(session.attendanceDate)} · ${session.tripType.label}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusChip(status: session.status),
                  // Sits inside the card's own InkWell, so that the delete
                  // route is reachable without leaving the list.
                  PopupMenuButton<_SessionAction>(
                    tooltip: 'Session actions',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) {
                      if (action == _SessionAction.delete) onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _SessionAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${session.present}/${session.total} present',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${session.percent.toStringAsFixed(0)}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: ratio, minHeight: 6),
              ),
              const SizedBox(height: Insets.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${session.absent} absent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: session.absent > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Roster',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: Insets.xxs),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SessionAction { delete }

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
