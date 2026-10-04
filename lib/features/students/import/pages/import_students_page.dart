import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../import_controller.dart';
import '../excel_import_models.dart';

/// Import screen: pick a workbook, review what would happen, then confirm.
///
/// Nothing is written until the user confirms, and the preview always shows
/// the four outcomes side by side so a bad sheet is obvious before it can do
/// any damage.
class ImportStudentsPage extends ConsumerStatefulWidget {
  const ImportStudentsPage({super.key});

  @override
  ConsumerState<ImportStudentsPage> createState() => _ImportStudentsPageState();
}

class _ImportStudentsPageState extends ConsumerState<ImportStudentsPage> {
  @override
  void initState() {
    super.initState();
    // "Import Excel" opens the picker straight away, which is the whole point
    // of the action that got the user here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentImportControllerProvider.notifier).pickAndPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentImportControllerProvider);
    final controller = ref.read(studentImportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Download sample template',
            onPressed: () => _downloadTemplate(context, controller),
          ),
        ],
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ImportState state,
    StudentImportController controller,
  ) {
    switch (state.status) {
      case ImportStatus.picking:
      case ImportStatus.parsing:
      case ImportStatus.importing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_busyLabel(state.status)),
            ],
          ),
        );

      case ImportStatus.preview:
        final preview = state.preview!;
        return _PreviewView(preview: preview, controller: controller);

      case ImportStatus.done:
        return _ResultView(summary: state.summary!);

      case ImportStatus.failed:
        return _ErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: controller.pickAndPreview,
        );

      case ImportStatus.idle:
        return _IdleView(onPick: controller.pickAndPreview);
    }
  }

  static String _busyLabel(ImportStatus status) => switch (status) {
    ImportStatus.picking => 'Waiting for file picker...',
    ImportStatus.parsing => 'Reading spreadsheet...',
    ImportStatus.importing => 'Adding students...',
    _ => '',
  };

  Future<void> _downloadTemplate(
    BuildContext context,
    StudentImportController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await controller.downloadTemplate();
    if (message == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Nothing chosen yet — the picker was dismissed.
class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_view_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('No file selected'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose Excel file'),
          ),
        ],
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose another file'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The preview: what was read, and what will be skipped, before committing.
class _PreviewView extends StatefulWidget {
  const _PreviewView({required this.preview, required this.controller});

  final ImportPreview preview;
  final StudentImportController controller;

  @override
  State<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<_PreviewView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;

    return Column(
      children: [
        _SourceCard(preview: preview),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _CountTab(label: 'New', count: preview.newStudents.length),
            _CountTab(label: 'Existing', count: preview.existing.length),
            _CountTab(label: 'Duplicates', count: preview.duplicates.length),
            _CountTab(label: 'Invalid', count: preview.invalid.length),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _StudentList(
                students: preview.newStudents
                    .map(
                      (draft) => _StudentRow(
                        rowNumber: draft.rowNumber,
                        rollNo: draft.rollNo,
                        name: draft.name,
                        institution: draft.institution,
                        boardingPoint: draft.boardingPoint,
                      ),
                    )
                    .toList(),
                emptyMessage: 'No new students in this file.',
              ),
              _StudentList(
                students: preview.existing
                    .map(
                      (match) => _StudentRow(
                        rowNumber: match.rowNumber,
                        rollNo: match.rollNo,
                        name: match.name,
                        institution: match.institution,
                        boardingPoint: match.boardingPoint,
                        note: match.hasChanges
                            ? 'Update available (details differ)'
                            : 'Already in OnBoard — no changes',
                      ),
                    )
                    .toList(),
                emptyMessage:
                    'No students already exist with these roll numbers.',
              ),
              _StudentList(
                students: preview.duplicates
                    .map(
                      (match) => _StudentRow(
                        rowNumber: match.rowNumber,
                        rollNo: match.rollNo,
                        name: match.name,
                        institution: match.institution,
                        boardingPoint: match.boardingPoint,
                        note: 'Same roll no as row ${match.firstRowNumber}',
                      ),
                    )
                    .toList(),
                emptyMessage: 'No repeated roll numbers in this file.',
              ),
              _StudentList(
                students: preview.invalid
                    .map(
                      (match) => _StudentRow(
                        rowNumber: match.rowNumber,
                        rollNo: match.rollNo,
                        name: match.name,
                        institution: match.institution,
                        boardingPoint: match.boardingPoint,
                        note: match.reason,
                        isProblem: true,
                      ),
                    )
                    .toList(),
                emptyMessage: 'Every row passed validation.',
              ),
            ],
          ),
        ),
        _ConfirmBar(preview: preview, controller: widget.controller),
      ],
    );
  }
}

/// File, worksheet and column mapping, so the user can see what was understood.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Sheet "${preview.sheetName}", header on row ${preview.headerRowNumber}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final field in ImportField.values)
                  Chip(
                    label: Text(
                      '${field.label}: ${preview.detectedColumns[field]}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final ignored in preview.ignoredColumns)
                  Chip(
                    label: Text(
                      '${ignored.letter}: ${ignored.columnLabel} (ignored)',
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
            if (preview.skippedEmptyRows > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${preview.skippedEmptyRows} empty '
                '${preview.skippedEmptyRows == 1 ? 'row' : 'rows'} ignored.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow {
  const _StudentRow({
    required this.rowNumber,
    required this.rollNo,
    required this.name,
    required this.institution,
    required this.boardingPoint,
    this.note,
    this.isProblem = false,
  });

  final int rowNumber;
  final String rollNo;
  final String name;
  final String institution;
  final String boardingPoint;
  final String? note;
  final bool isProblem;
}

class _StudentList extends StatelessWidget {
  const _StudentList({required this.students, required this.emptyMessage});

  final List<_StudentRow> students;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      student.rollNo.isEmpty ? '(no roll no)' : student.rollNo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Row ${student.rowNumber}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (student.name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(student.name, style: theme.textTheme.bodyLarge),
                ],
                if (student.institution.isNotEmpty)
                  Text(student.institution, style: theme.textTheme.bodyMedium),
                if (student.boardingPoint.isNotEmpty)
                  Text(
                    student.boardingPoint,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (student.note != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        student.isProblem
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        size: 16,
                        color: student.isProblem
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          student.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: student.isProblem
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom bar stating exactly what will happen if the user confirms.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.preview, required this.controller});

  final ImportPreview preview;
  final StudentImportController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skipped = preview.skippedCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.canImport
                  ? [
                      if (preview.newStudents.isNotEmpty)
                        'Add ${preview.newStudents.length} new ${preview.newStudents.length == 1 ? "student" : "students"}',
                      if (preview.updatedStudents.isNotEmpty)
                        'Update ${preview.updatedStudents.length} existing ${preview.updatedStudents.length == 1 ? "student" : "students"}',
                    ].join(' and ') + '?'
                  : 'Nothing to add or update',
              style: theme.textTheme.titleSmall,
            ),
            if (skipped > 0)
              Text(
                '$skipped ${skipped == 1 ? 'row' : 'rows'} will be skipped: '
                '${preview.existing.length - preview.updatedStudents.length} unchanged in OnBoard, '
                '${preview.duplicates.length} duplicate roll no, '
                '${preview.invalid.length} invalid.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.pickAndPreview,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Choose other file'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: preview.canImport
                        ? () => _confirm(context)
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final newCount = preview.newStudents.length;
    final updateCount = preview.updatedStudents.length;
    final parts = [
      if (newCount > 0) 'add $newCount new ${newCount == 1 ? "student" : "students"}',
      if (updateCount > 0) 'update $updateCount existing ${updateCount == 1 ? "student" : "students"}',
    ].join(' and ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text('This will $parts in your directory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await controller.confirmImport();
    }
  }
}

/// Final report shown once the import has been committed.
class _ResultView extends ConsumerWidget {
  const _ResultView({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Import complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${summary.fileName} · ${summary.sheetName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _ResultTile(
              icon: Icons.person_add_alt_1,
              color: theme.colorScheme.primary,
              label: 'Added',
              value: summary.added,
            ),
            if (summary.updated > 0)
              _ResultTile(
                icon: Icons.edit_note,
                color: theme.colorScheme.secondary,
                label: 'Updated',
                value: summary.updated,
              ),
            _ResultTile(
              icon: Icons.person_off_outlined,
              color: theme.colorScheme.tertiary,
              label: 'Skipped, unchanged in OnBoard',
              value: summary.existingSkipped,
            ),
            _ResultTile(
              icon: Icons.content_copy,
              color: theme.colorScheme.tertiary,
              label: 'Skipped, duplicate roll no',
              value: summary.duplicatesSkipped,
            ),
            _ResultTile(
              icon: Icons.error_outline,
              color: theme.colorScheme.error,
              label: 'Skipped, invalid',
              value: summary.invalidSkipped,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(studentImportControllerProvider.notifier).reset();
                if (context.mounted) context.pop();
              },
              icon: const Icon(Icons.done),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
