import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/export/data_export_service.dart';
import '../../attendance/models/attendance_models.dart';
import '../dashboard_service.dart';

/// The home screen: today's snapshot, all-time totals and shortcuts.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final today = formatDate(DateTime.now());

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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(today, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              _TodayCard(data: data),
              const SizedBox(height: 20),
              _QuickActions(),
              const SizedBox(height: 24),
              _SectionHeader('Overview'),
              _StatsGrid(data: data),
              const SizedBox(height: 24),
              _SectionHeader('Recent sessions'),
              if (data.recentSessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No attendance taken yet.'),
                )
              else
                for (final session in data.recentSessions)
                  _RecentSessionTile(session: session),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('No attendance taken today.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/attendance'),
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('Take attendance'),
              ),
            ],
          ),
        ),
      );
    }

    final morning = data.morningToday;
    final evening = data.eveningToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Today', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (morning != null) ...[
              _TripProgressRow(session: morning),
              const SizedBox(height: 12),
            ],
            if (evening != null) ...[
              _TripProgressRow(session: evening),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/attendance'),
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Take attendance'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.go('/history'),
                  child: const Text('View history'),
                ),
              ],
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

    return InkWell(
      onTap: () => context.push('/history/${session.sessionId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${session.tripType.label} Trip',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    session.status == AttendanceSessionStatus.open
                        ? 'Open'
                        : 'Completed',
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.present}/${session.total} (${session.percent.toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: ratio),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.groups_outlined,
            label: 'Students',
            onTap: () => context.go('/students'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.history_outlined,
            label: 'History',
            onTap: () => context.go('/history'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_outlined,
            label: 'Reports',
            onTap: () => context.go('/reports'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final report = data.allTime;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Stat(label: 'Students', value: '${data.studentCount}'),
        _Stat(label: 'Sessions', value: '${report.sessionCount}'),
        _Stat(label: 'Present', value: '${report.totalPresent}'),
        _Stat(label: 'Absent', value: '${report.totalAbsent}'),
        _Stat(
          label: 'Attendance',
          value: '${report.overallPercent.toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall),
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
    final isMorning = session.tripType == TripType.morning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/history/${session.sessionId}'),
        leading: Icon(
          isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
        ),
        title: Text(
          '${formatDate(session.attendanceDate)} · ${session.tripType.label}',
        ),
        subtitle: Text(
          '${session.present}/${session.total} present · '
          '${session.percent.toStringAsFixed(1)}%',
        ),
        trailing: const Icon(Icons.chevron_right),
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
