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
      padding: EdgeInsets.fromLTRB(
        8,
        4,
        8,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final theme = Theme.of(context);
        final isPresent = entry.isPresent;
        final studentName = entry.student.name.isNotEmpty
            ? entry.student.name
            : entry.student.rollNo;
        final avatarLetter = studentName.isNotEmpty
            ? studentName[0].toUpperCase()
            : '?';

        return Semantics(
          label: '$studentName, ${entry.student.rollNo}, ${isPresent ? "Present" : "Absent"}',
          child: Card(
            elevation: 0,
            color: isPresent
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainer,
            child: ListTile(
              onTap: onStudentTap != null ? () => onStudentTap!(entry) : null,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: isPresent
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isPresent
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    child: Text(avatarLetter),
                  ),
                  if (isPresent)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                studentName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${entry.student.rollNo} • ${entry.student.boardingPoint}',
              ),
              trailing: isPresent
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      semanticLabel: 'Present',
                    )
                  : (state.isActive
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Mark Present',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: onStudentTap != null
                              ? () => onStudentTap!(entry)
                              : null,
                        )
                      : Icon(
                          Icons.radio_button_unchecked,
                          color: theme.colorScheme.onSurfaceVariant,
                          semanticLabel: 'Absent',
                        )),
            ),
          ),
        );
      },
    );
  }
}
