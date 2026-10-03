import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../barcode_models.dart';

/// Renders the outcome of one barcode match.
///
/// Shared by the camera screen and the manual-entry screen so both report
/// success in exactly the same terms. The scanned value is always shown as it
/// was received, alongside what it was interpreted as.
class BarcodeResultCard extends StatelessWidget {
  const BarcodeResultCard({super.key, required this.result, this.onDismiss});

  final BarcodeMatchResult result;

  /// When supplied, a control to clear the result is shown.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, colour) = switch (result.status) {
      BarcodeMatchStatus.matched => (
        Icons.check_circle_outline,
        'Student Found',
        theme.colorScheme.primary,
      ),
      BarcodeMatchStatus.notFound => (
        Icons.person_off_outlined,
        'Student Not Found',
        theme.colorScheme.error,
      ),
      BarcodeMatchStatus.ambiguous => (
        Icons.warning_amber_rounded,
        'Ambiguous Barcode',
        theme.colorScheme.tertiary,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colour, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colour,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear result',
                    onPressed: onDismiss,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _BarcodeLine(
              label: 'Scanned',
              value: result.barcode,
              emphasise: true,
            ),
            const SizedBox(height: 8),
            if (result.isMatched && result.student != null) ...[
              _StudentDetails(student: result.student!),
            ] else if (result.isAmbiguous) ...[
              _AmbiguousDetails(candidates: result.candidates),
            ] else ...[
              Text(
                'No registered roll number appears in this barcode.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows what was scanned next to what it means, because a card can carry a
/// prefix the app deliberately ignores.
class _BarcodeLine extends StatelessWidget {
  const _BarcodeLine({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value.isEmpty ? '(empty)' : value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            display,
            style: emphasise
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _StudentDetails extends StatelessWidget {
  const _StudentDetails({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _BarcodeLine(label: 'Roll No', value: student.rollNo),
        _BarcodeLine(label: 'School', value: student.institution),
        _BarcodeLine(label: 'Boarding', value: student.boardingPoint),
      ],
    );
  }
}

class _AmbiguousDetails extends StatelessWidget {
  const _AmbiguousDetails({required this.candidates});

  final List<Student> candidates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This barcode contains ${candidates.length} registered roll numbers. '
          'OnBoard will not guess which student was meant.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final student in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${student.rollNo} — ${student.name}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
