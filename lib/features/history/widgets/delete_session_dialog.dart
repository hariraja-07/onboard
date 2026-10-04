import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/models/attendance_models.dart';
import '../history_controller.dart';

/// Confirms, then performs, the deletion of one attendance session.
///
/// Shared by the History list and the session details screen so that both ask
/// the same question in the same words before anything is removed, and so that
/// a safety copy of the database is always written first.
///
/// Returns whether the session was actually deleted, so a caller sitting on the
/// deleted session's own screen can leave it.
Future<bool> confirmDeleteSession(
  BuildContext context,
  WidgetRef ref,
  AttendanceSessionSummary summary,
) async {
  final scheme = Theme.of(context).colorScheme;
  final when = formatHistoryDate(summary.attendanceDate);
  final records = summary.present;
  final recordWord = records == 1 ? 'record' : 'records';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this session?'),
      content: Text(
        'The $when ${summary.tripType.label.toLowerCase()} session will be '
        'deleted, along with the $records attendance $recordWord taken in it.\n\n'
        'A safety copy of your data is saved first, so this can be undone from '
        'Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  final notifier = ref.read(historyMutationProvider.notifier);
  final result = await notifier.deleteSession(summary);
  notifier.acknowledge();

  if (!context.mounted) return false;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.error ?? result.message ?? 'Session deleted.'),
        // Floating so the confirmation clears the list instead of covering a
        // row, which matters on the details screen where it would sit on top of
        // the roster.
        behavior: SnackBarBehavior.floating,
      ),
    );

  return result.error == null;
}
