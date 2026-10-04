import 'package:flutter/material.dart';
import '../attendance_controller.dart';
import '../models/attendance_models.dart';

/// Renders the session roster for the selected filter in a phone-first
/// responsive layout.
class AttendanceRosterTable extends StatelessWidget {
  const AttendanceRosterTable({
    super.key,
    required this.state,
    required this.filtered,
    required this.filter,
    this.onStudentTap,
  });

  final AttendanceState state;
  final List<StudentAttendance> filtered;
  final AttendanceFilter filter;
  final void Function(StudentAttendance entry)? onStudentTap;

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No students match the current filters'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final theme = Theme.of(context);
        final isPresent = entry.isPresent;
        final avatarLetter = entry.student.name.isNotEmpty
            ? entry.student.name[0].toUpperCase()
            : (entry.student.rollNo.isNotEmpty
                ? entry.student.rollNo[0].toUpperCase()
                : '?');

        return Card(
          elevation: 0,
          color: isPresent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainer,
          child: ListTile(
            onTap: onStudentTap != null ? () => onStudentTap!(entry) : null,
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
              entry.student.name.isNotEmpty
                  ? entry.student.name
                  : entry.student.rollNo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${entry.student.rollNo} • ${entry.student.boardingPoint}',
            ),
            trailing: isPresent
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : (state.isActive
                    ? IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Mark Present',
                        onPressed: onStudentTap != null
                            ? () => onStudentTap!(entry)
                            : null,
                      )
                    : const Icon(Icons.radio_button_unchecked)),
          ),
        );
      },
    );
  }
}
