import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/export/data_export_service.dart';
import '../settings_controller.dart';

/// Shows what a chosen backup contains and asks for explicit confirmation
/// before replacing the current data.
class RestoreDataPage extends ConsumerWidget {
  const RestoreDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataManagementControllerProvider);
    final controller = ref.read(dataManagementControllerProvider.notifier);
    final info = state.pendingInfo;

    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restore data')),
        body: const Center(child: Text('No backup selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restore data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Backup contents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow('Students', '${info.studentCount}'),
                  _InfoRow('Attendance sessions', '${info.sessionCount}'),
                  _InfoRow('Attendance records', '${info.recordCount}'),
                  _InfoRow('Roster entries', '${info.rosterCount}'),
                  if (info.earliestSession != null &&
                      info.latestSession != null)
                    _InfoRow(
                      'Date range',
                      '${formatDate(info.earliestSession!)} to '
                          '${formatDate(info.latestSession!)}',
                    ),
                  _InfoRow('Backed up', formatDateTime(info.exportedAt)),
                  _InfoRow('Made with', 'OnBoard ${info.appVersion}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Restoring replaces all students and attendance currently in '
                'the app with the contents of this backup. A safety copy of '
                'the current data is saved automatically first.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: state.isBusy
                ? null
                : () => _confirmAndRestore(context, ref, controller),
            icon: const Icon(Icons.restore),
            label: const Text('Restore this backup'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: state.isBusy
                ? null
                : () {
                    controller.cancelRestore();
                    context.pop();
                  },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRestore(
    BuildContext context,
    WidgetRef ref,
    DataManagementController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'Your current students and attendance will be replaced. '
          'This cannot be undone in the app, but a safety backup will be '
          'saved automatically so it can be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await controller.confirmRestore();
    if (!context.mounted) return;

    final result = ref.read(dataManagementControllerProvider);
    final text = result.error ?? result.message;
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
    controller.acknowledge();
    if (result.status == DataManagementStatus.done) {
      context.pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
