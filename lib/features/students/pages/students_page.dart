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
  @override
  void initState() {
    super.initState();
    ref.read(studentsProvider.notifier).loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentsProvider);

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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...institutions.map((i) => DropdownMenuItem(value: i, child: Text(i))),
                    ],
                    onChanged: (value) => notifier.setInstitutionFilter(value?.isNotEmpty == true ? value : null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.boardingPointFilter,
                    decoration: const InputDecoration(
                      labelText: 'Boarding Point',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...boardingPoints.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                    ],
                    onChanged: (value) => notifier.setBoardingPointFilter(value?.isNotEmpty == true ? value : null),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (state.searchQuery.isNotEmpty || state.institutionFilter != null || state.boardingPointFilter != null) ...[
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(studentsProvider.notifier).clearFilters(),
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
      return Center(child: Text('Error: ${state.error}'));
    }

    final students = state.filteredStudents;

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text('Tap + to add a student'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              student.rollNo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(student.name, style: Theme.of(context).textTheme.bodyLarge),
                Text(student.institution, style: TextStyle(color: Colors.grey.shade600)),
                Text(student.boardingPoint, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showStudentForm(context, student: student),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _confirmDelete(context, student.id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStudentForm(BuildContext context, {Student? student}) {
    final isEditing = student != null;
    final rollNoCtrl = TextEditingController(text: student?.rollNo ?? '');
    final nameCtrl = TextEditingController(text: student?.name ?? '');
    final institutionCtrl = TextEditingController(text: student?.institution ?? '');
    final boardingPointCtrl = TextEditingController(text: student?.boardingPoint ?? '');

    if (!isEditing) {
      rollNoCtrl.addListener(() => rollNoCtrl.text = rollNoCtrl.text.toUpperCase());
    }

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
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  isEditing ? 'Edit Student' : 'Add Student',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (!isEditing) ...[
                  TextFormField(
                    controller: rollNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
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
                    if (v == null || v.trim().isEmpty) return 'Required';
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
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final rollNo = rollNoCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    final institution = institutionCtrl.text.trim();
                    final boardingPoint = boardingPointCtrl.text.trim();

                    if (rollNo.isEmpty || name.isEmpty || institution.isEmpty || boardingPoint.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    final notifier = ref.read(studentsProvider.notifier);
                    bool success;
                    final navigator = Navigator.of(ctx);

                    if (isEditing) {
                      success = await notifier.editStudent(
                        id: student.id,
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
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
        content: const Text('Are you sure you want to delete this student?'),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}