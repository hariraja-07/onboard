import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/export/data_export_service.dart';
import '../../../core/widgets/skeleton.dart';
import '../../attendance/models/attendance_models.dart';
import '../dashboard_service.dart';

/// The home screen: today's snapshot, high-level summary and recent sessions.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static String _formatDisplayDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    final dayName = days[local.weekday - 1];
    final monthName = months[local.month - 1];
    return '$dayName, ${local.day} $monthName ${local.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final theme = Theme.of(context);
    final todayDisplay = _formatDisplayDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: dashboard.when(
          loading: () => const _DashboardSkeleton(),
          error: (error, _) => _ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                todayDisplay,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _TodayCard(data: data),
              const SizedBox(height: 24),
              const _SectionHeader('Overview'),
              const SizedBox(height: 8),
              _StatsOverview(data: data),
              const SizedBox(height: 24),
              const _SectionHeader('Recent sessions'),
              const SizedBox(height: 8),
              if (data.recentSessions.isEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Center(
                      child: Text(
                        'No attendance taken yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < data.recentSessions.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _RecentSessionTile(session: data.recentSessions[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = data.todaySessions;

    if (sessions.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.today_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Attendance",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No attendance taken today.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/attendance'),
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Take Attendance'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final morning = data.morningToday;
    final evening = data.eveningToday;
    final hasOpenSession = sessions.any(
      (s) => s.status == AttendanceSessionStatus.open,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's Attendance",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (morning != null) ...[
              _TripProgressRow(session: morning),
              if (evening != null) const Divider(height: 24),
            ],
            if (evening != null) ...[
              _TripProgressRow(session: evening),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/attendance'),
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: Text(
                  hasOpenSession
                      ? 'Resume Attendance'
                      : 'Take Attendance',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripProgressRow extends StatelessWidget {
  const _TripProgressRow({required this.session});

  final AttendanceSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMorning = session.tripType == TripType.morning;
    final ratio = session.total == 0 ? 0.0 : session.present / session.total;
    final isOpen = session.status == AttendanceSessionStatus.open;

    return InkWell(
      onTap: () => context.push('/history/${session.sessionId}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMorning
                      ? Icons.wb_sunny_outlined
                      : Icons.nights_stay_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${session.tripType.label} Trip',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'In Progress' : 'Completed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOpen
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${session.present} of ${session.total} present',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${session.percent.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewTile(
            icon: Icons.groups_outlined,
            label: 'Enrolled Students',
            value: '${data.studentCount}',
            onTap: () => context.go('/students'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OverviewTile(
            icon: Icons.event_note_outlined,
            label: 'Total Sessions',
            value: '${data.allTime.sessionCount}',
            onTap: () => context.go('/history'),
          ),
        ),
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  const _RecentSessionTile({required this.session});

  final AttendanceSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMorning = session.tripType == TripType.morning;

    return ListTile(
      onTap: () => context.push('/history/${session.sessionId}'),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        '${session.tripType.label} Trip',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${formatDate(session.attendanceDate)} · ${session.present}/${session.total} present (${session.percent.toStringAsFixed(0)}%)',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text(
          'Could not load dashboard.\n$message',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const SkeletonBox(width: 140, height: 16),
        const SizedBox(height: 12),
        const SkeletonBox(width: double.infinity, height: 140, radius: 16),
        const SizedBox(height: 24),
        const SkeletonBox(width: 100, height: 20),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 100,
                radius: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 100,
                radius: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonBox(width: 120, height: 20),
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 120, radius: 16),
      ],
    );
  }
}

