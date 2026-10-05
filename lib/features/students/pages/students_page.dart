import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../students_controller.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/skeleton.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Deferred: loadStudents publishes its loading state immediately, and
    // mutating a provider while the tree is building is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(studentsProvider.notifier).loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentsProvider);

    ref.listen<StudentsState>(studentsProvider, (previous, next) {
      final message = next.actionMessage;
      final error = next.actionError;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        ref.read(studentsProvider.notifier).clearActionFeedback();
      } else if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        ref.read(studentsProvider.notifier).clearActionFeedback();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: () => context.push('/students/import'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(state),
          _buildStats(state),
          Expanded(child: _buildStudentList(state)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  Widget _buildFilters(StudentsState state) {
    final notifier = ref.read(studentsProvider.notifier);
    final institutions = state.institutions;
    final boardingPoints = state.boardingPoints;

    return Card(
      margin: Insets.allSm,
      child: Padding(
        padding: Insets.allSm,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: notifier.setSearchQuery,
            ),
            const SizedBox(height: Insets.xs),
            DropdownButtonFormField<String>(
              isExpanded: true,
              isDense: true,
              initialValue: state.institutionFilter,
              decoration: const InputDecoration(
                labelText: 'Institution',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All Institutions'),
                ),
                ...institutions.map(
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => notifier.setInstitutionFilter(
                value?.isNotEmpty == true ? value : null,
              ),
            ),
            const SizedBox(height: Insets.xs),
            DropdownButtonFormField<String>(
              isExpanded: true,
              isDense: true,
              initialValue: state.boardingPointFilter,
              decoration: const InputDecoration(
                labelText: 'Boarding Point',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All Boarding Points'),
                ),
                ...boardingPoints.map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => notifier.setBoardingPointFilter(
                value?.isNotEmpty == true ? value : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(StudentsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: Row(
        children: [
          Text(
            '${state.filteredStudents.length} student${state.filteredStudents.length != 1 ? 's' : ''}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (state.searchQuery.isNotEmpty ||
              state.institutionFilter != null ||
              state.boardingPointFilter != null) ...[
            const Spacer(),
            TextButton(
              onPressed: () {
                _searchController.clear();
                ref.read(studentsProvider.notifier).clearFilters();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentList(StudentsState state) {
    if (state.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.xs, Insets.sm, 88),
        itemCount: 6,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: Insets.xs),
          child: SkeletonBox(width: double.infinity, height: 72, radius: 12),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: Insets.allLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Could not load students',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: Insets.md),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(studentsProvider.notifier).loadStudents(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final students = state.filteredStudents;

    if (students.isEmpty) {
      final filteredOut = state.students.isNotEmpty;
      return Center(
        child: Padding(
          padding: Insets.allLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filteredOut ? Icons.search_off : Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: Insets.md),
              Text(
                filteredOut
                    ? 'No students match your filters'
                    : 'No students yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xs),
              if (filteredOut)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(studentsProvider.notifier).clearFilters();
                  },
                  child: const Text('Clear filters'),
                )
              else
                const Text('Tap "Add Student" to get started'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.xs, Insets.sm, 88),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final theme = Theme.of(context);
        return Card(
          margin: EdgeInsets.only(bottom: Insets.xs),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            onTap: () => _showStudentForm(context, student: student),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Insets.xxs),
                Text(
                  '${student.rollNo} • ${student.boardingPoint}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (student.institution.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      student.institution,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showStudentForm(context, student: student),
              tooltip: 'Edit',
            ),
          ),
        );
      },
    );
  }

  void _showStudentForm(BuildContext context, {Student? student}) {
    final isEditing = student != null;
    final formKey = GlobalKey<FormState>();
    final rollNoCtrl = TextEditingController(text: student?.rollNo ?? '');
    final nameCtrl = TextEditingController(text: student?.name ?? '');
    final institutionCtrl = TextEditingController(
      text: student?.institution ?? '',
    );
    final boardingPointCtrl = TextEditingController(
      text: student?.boardingPoint ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              MediaQuery.of(ctx).viewInsets.bottom + Insets.lg,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditing ? 'Edit Student' : 'Add Student',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Insets.md),
                  TextFormField(
                    controller: rollNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number *',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Roll number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  TextFormField(
                    controller: institutionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Institution *',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Institution is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  TextFormField(
                    controller: boardingPointCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Boarding Point *',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Boarding point is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final rollNo = rollNoCtrl.text.trim();
                      final name = nameCtrl.text.trim();
                      final institution = institutionCtrl.text.trim();
                      final boardingPoint = boardingPointCtrl.text.trim();

                      final notifier = ref.read(studentsProvider.notifier);
                      bool success;
                      final navigator = Navigator.of(ctx);

                      if (isEditing) {
                        success = await notifier.editStudent(
                          id: student.id,
                          rollNo: rollNo,
                          name: name,
                          institution: institution,
                          boardingPoint: boardingPoint,
                        );
                      } else {
                        success = await notifier.addStudent(
                          rollNo: rollNo,
                          name: name,
                          institution: institution,
                          boardingPoint: boardingPoint,
                        );
                      }

                      if (success && mounted) {
                        navigator.pop();
                      }
                    },
                    child: Text(isEditing ? 'Update' : 'Add'),
                  ),
                  const SizedBox(height: Insets.xs),
                  if (isEditing)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(context, student.id);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Delete Student'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text(
          'Delete this student? Their attendance records will be removed too. '
          'Past sessions keep the name they were taken with.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(studentsProvider.notifier).deleteStudent(id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
