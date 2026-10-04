import 'package:flutter/material.dart';

import '../attendance_controller.dart';
import '../models/attendance_models.dart';

/// A compact banner showing the result of the most recent scan.
///
/// Preserves the exact outcome label from [AttendanceScanOutcome] and shows
/// which student was involved where applicable.
class AttendanceResultBanner extends StatelessWidget {
  const AttendanceResultBanner({super.key, required this.state});

  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    final outcome = state.lastOutcome;
    if (outcome == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = _backgroundColor(theme, outcome);
    final foreground = _foregroundColor(theme, outcome);
    final icon = _icon(outcome);

    final student = state.lastStudent;
    final line1 = outcome.label;
    final line2 = switch (outcome) {
      AttendanceScanOutcome.marked =>
        student != null
            ? (student.name.isNotEmpty
                ? '${student.name} (${student.rollNo})'
                : student.rollNo)
            : null,
      AttendanceScanOutcome.alreadyPresent =>
        student != null
            ? (student.name.isNotEmpty
                ? '${student.name} (${student.rollNo})'
                : student.rollNo)
            : null,
      AttendanceScanOutcome.notFound =>
        state.lastBarcode != null && state.lastBarcode!.isNotEmpty
            ? 'Barcode: ${state.lastBarcode}'
            : '',
      AttendanceScanOutcome.ambiguous =>
        state.lastBarcode != null && state.lastBarcode!.isNotEmpty
            ? 'Ambiguous barcode: ${state.lastBarcode}'
            : '',
    };
    final line3 = student != null &&
            (outcome == AttendanceScanOutcome.marked ||
                outcome == AttendanceScanOutcome.alreadyPresent)
        ? '${student.boardingPoint}${student.institution.isNotEmpty ? ' • ${student.institution}' : ''}'
        : null;

    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  if (line2 != null && line2.isNotEmpty)
                    Text(
                      line2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (line3 != null && line3.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: foreground,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              line3,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _backgroundColor(ThemeData theme, AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return theme.colorScheme.primaryContainer;
      case AttendanceScanOutcome.alreadyPresent:
        return theme.colorScheme.tertiaryContainer;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return theme.colorScheme.errorContainer;
    }
  }

  Color _foregroundColor(ThemeData theme, AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return theme.colorScheme.onPrimaryContainer;
      case AttendanceScanOutcome.alreadyPresent:
        return theme.colorScheme.onTertiaryContainer;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return theme.colorScheme.onErrorContainer;
    }
  }

  IconData _icon(AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return Icons.check_circle;
      case AttendanceScanOutcome.alreadyPresent:
        return Icons.info;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return Icons.warning;
    }
  }
}
