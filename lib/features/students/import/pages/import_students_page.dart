import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../import_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/spacing.dart';
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
              const SizedBox(height: Insets.md),
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
        return _IdleView(
          onPick: controller.pickAndPreview,
          onDownloadTemplate: () => _downloadTemplate(context, controller),
        );
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

/// Landing onboarding view when no file is currently selected.
class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick, required this.onDownloadTemplate});

  final VoidCallback onPick;
  final VoidCallback onDownloadTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: Insets.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Import Student Roster',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Upload an Excel (.xlsx) file with student roll numbers, names, institutions, and boarding points.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose Excel File (.xlsx)'),
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: onDownloadTemplate,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download Sample Template'),
            ),
          ],
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
    return Center(
      child: SingleChildScrollView(
        padding: Insets.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: Insets.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Insets.lg),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // The header carries the file summary and the Add/Update/Skip counts.
        // Capping it as a share of the viewport and letting it scroll
        // internally keeps a wide sheet's column mapping from squeezing the
        // roster away or pushing the pinned TabBar and confirm bar off
        // screen. The roster keeps whatever vertical space is left over.
        final headerMaxHeight = (constraints.maxHeight * 0.35).clamp(
          96.0,
          260.0,
        );

        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: headerMaxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SourceCard(preview: preview),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xxs,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SummaryBadge(
                            label: 'To Add',
                            count: preview.newStudents.length,
                            tone: _BadgeTone.success,
                          ),
                          _SummaryBadge(
                            label: 'To Update',
                            count: preview.updatedStudents.length,
                            tone: _BadgeTone.info,
                          ),
                          _SummaryBadge(
                            label: 'To Skip',
                            count: preview.skippedCount,
                            tone: _BadgeTone.warning,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                _CountTab(label: 'New', count: preview.newStudents.length),
                _CountTab(label: 'Existing', count: preview.existing.length),
                _CountTab(
                  label: 'Duplicates',
                  count: preview.duplicates.length,
                ),
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
      },
    );
  }
}

/// File, worksheet and column mapping, so the user can see what was understood.
///
/// A real export names every unmapped column in the sheet, so the mapping is
/// collapsed behind a one line summary and the chips are capped. The enclosing
/// preview header caps and scrolls this card, so an expanded mapping stays
/// reachable on a short viewport instead of overflowing the column.
class _SourceCard extends StatefulWidget {
  const _SourceCard({required this.preview});

  final ImportPreview preview;

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

/// How many ignored-column chips are listed before collapsing into a count.
const _maxVisibleIgnoredChips = 6;

class _SourceCardState extends State<_SourceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;

    return Card(
      margin: Insets.allSm,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.sm,
                Insets.sm,
                Insets.xs,
                Insets.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 20),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.fileName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sheet "${preview.sheetName}", header on row ${preview.headerRowNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.xxs),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    semanticLabel: _expanded
                        ? 'Hide column mapping'
                        : 'Show column mapping',
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.sm,
                0,
                Insets.sm,
                Insets.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      for (final ignored in preview.ignoredColumns.take(
                        _maxVisibleIgnoredChips,
                      ))
                        Chip(
                          label: Text(
                            '${ignored.letter}: ${ignored.columnLabel} (ignored)',
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      if (preview.ignoredColumns.length >
                          _maxVisibleIgnoredChips)
                        Chip(
                          label: Text(
                            '+${preview.ignoredColumns.length - _maxVisibleIgnoredChips} more',
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                    ],
                  ),
                  if (preview.skippedEmptyRows > 0) ...[
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${preview.skippedEmptyRows} empty '
                      '${preview.skippedEmptyRows == 1 ? 'row' : 'rows'} ignored.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
        ],
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
          const SizedBox(width: Insets.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.xs,
              vertical: 2,
            ),
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
          padding: Insets.allLg,
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final theme = Theme.of(context);

        return Card(
          margin: EdgeInsets.only(bottom: Insets.xs),
          child: Padding(
            padding: Insets.allSm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.rollNo.isEmpty
                            ? '(no roll no)'
                            : student.rollNo,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      'Row ${student.rowNumber}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (student.name.isNotEmpty) ...[
                  const SizedBox(height: Insets.xxs),
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
                  const SizedBox(height: Insets.xs),
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
                      const SizedBox(width: Insets.xs),
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
        padding: Insets.allSm,
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
                    ].join(' and ?')
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
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.pickAndPreview,
                    icon: const Icon(Icons.upload_file, size: 18),
                    // Single line so a narrow window cannot wrap the label and
                    // grow this bar into the roster's vertical space.
                    label: const Text(
                      'Choose file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: preview.canImport
                        ? () => _confirm(context)
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Import',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      if (newCount > 0)
        'add $newCount new ${newCount == 1 ? "student" : "students"}',
      if (updateCount > 0)
        'update $updateCount existing ${updateCount == 1 ? "student" : "students"}',
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
        padding: Insets.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Insets.md),
            Text('Import complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: Insets.xxs),
            Text(
              '${summary.fileName} · ${summary.sheetName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.lg),
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
            const SizedBox(height: Insets.lg),
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
      margin: EdgeInsets.only(bottom: Insets.xs),
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

/// A single To Add / To Update / To Skip counter.
///
/// Deliberately not an [Expanded]: the preview stacks these in a [Wrap] so
/// they wrap onto a second line at large text scales instead of overflowing.
/// Outcome a row falls into after an import is previewed.
///
/// Each tone carries its own container and foreground rather than tinting one
/// shared colour, so the three read as equal peers. The old implementation
/// tinted at a fixed 12% and picked the label from `MaterialColor.shade800`,
/// which put 11px text at 3.87:1 on the badge in light mode.
enum _BadgeTone { success, info, warning }

extension on _BadgeTone {
  (Color container, Color onContainer) resolve(
    BuildContext context, {
    required ColorScheme scheme,
  }) => switch (this) {
    _BadgeTone.success => (
      AppColors.successContainer(context),
      AppColors.onSuccessContainer(context),
    ),
    _BadgeTone.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
    _BadgeTone.warning => (
      AppColors.warningContainer(context),
      AppColors.warning(context),
    ),
  };
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (container, onContainer) = tone.resolve(
      context,
      scheme: theme.colorScheme,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.xs,
        horizontal: Insets.sm,
      ),
      decoration: BoxDecoration(color: container, borderRadius: Radii.allXs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: onContainer,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: onContainer),
          ),
        ],
      ),
    );
  }
}
