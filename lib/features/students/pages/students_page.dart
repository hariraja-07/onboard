import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../students_controller.dart';
import '../../../core/database/database.dart';

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
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setSearchQuery,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.institutionFilter,
                    decoration: const InputDecoration(
                      labelText: 'Institution',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...institutions.map(
                        (i) => DropdownMenuItem(value: i, child: Text(i)),
                      ),
                    ],
                    onChanged: (value) => notifier.setInstitutionFilter(
                      value?.isNotEmpty == true ? value : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.boardingPointFilter,
                    decoration: const InputDecoration(
                      labelText: 'Boarding Point',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...boardingPoints.map(
                        (b) => DropdownMenuItem(value: b, child: Text(b)),
                      ),
                    ],
                    onChanged: (value) => notifier.setBoardingPointFilter(
                      value?.isNotEmpty == true ? value : null,
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

  Widget _buildStats(StudentsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load students',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filteredOut ? Icons.search_off : Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 8),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            onTap: () => _showStudentForm(context, student: student),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  isEditing ? 'Edit Student' : 'Add Student',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: rollNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Roll Number *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Roll number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: institutionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Institution *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Institution is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: boardingPointCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Boarding Point *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Boarding point is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 8),
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
