import 'package:flutter/material.dart';
import '../attendance_controller.dart';
import '../models/attendance_models.dart';

/// Renders the session roster for the selected filter in a phone-first
/// responsive layout. On narrow widths a simple list is shown; the code is
/// structured to allow a DataTable on wide layouts without changing the API.
class AttendanceRosterTable extends StatelessWidget {
  const AttendanceRosterTable({
    super.key,
    required this.state,
    required this.filtered,
    required this.filter,
  });

  final AttendanceState state;
  final List<StudentAttendance> filtered;
  final AttendanceFilter filter;

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
        return Card(
          elevation: 0,
          color: isPresent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainer,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                entry.student.rollNo.isNotEmpty
                    ? entry.student.rollNo[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(
              entry.student.name.isNotEmpty
                  ? entry.student.name
                  : entry.student.rollNo,
            ),
            subtitle: Text(entry.student.rollNo),
            trailing: isPresent
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : const Icon(Icons.radio_button_unchecked),
          ),
        );
      },
    );
  }
}
