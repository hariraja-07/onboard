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
    this.onTogglePresent,
  });

  final AttendanceState state;
  final List<StudentAttendance> filtered;
  final AttendanceFilter filter;

  /// Marks an absent student present. Never undoes.
  final void Function(StudentAttendance entry)? onStudentTap;

  /// Marks an absent student present, or undoes an existing mark.
  ///
  /// Separate from [onStudentTap] so tapping the row stays a one-way action
  /// and cannot silently drop a student's attendance: undo has to be the
  /// deliberate tap on the trailing control.
  final void Function(StudentAttendance entry)? onTogglePresent;

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
              trailing: _trailingControl(context, entry, isPresent),
            ),
          ),
        );
      },
    );
  }

  /// The right-hand control: undo on a present row, mark otherwise.
  ///
  /// Only ever one control, so there is a single 48x48 target and the two
  /// actions cannot be confused with each other or with the row tap.
  Widget _trailingControl(
    BuildContext context,
    StudentAttendance entry,
    bool isPresent,
  ) {
    final theme = Theme.of(context);
    if (!state.isActive) {
      return Icon(
        isPresent ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isPresent
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        semanticLabel: isPresent ? 'Present' : 'Absent',
      );
    }

    final onPressed = onTogglePresent ?? onStudentTap;
    return IconButton(
      icon: Icon(
        isPresent ? Icons.remove_circle_outline : Icons.add_circle_outline,
      ),
      tooltip: isPresent ? 'Undo Present' : 'Mark Present',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed == null ? null : () => onPressed(entry),
    );
  }
}
