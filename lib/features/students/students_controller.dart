import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/repositories/student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(AppDatabase.instance);
});

final studentsProvider = StateNotifierProvider<StudentsNotifier, StudentsState>((ref) {
  return StudentsNotifier(ref.read(studentRepositoryProvider));
});

class StudentsState {
  final List<Student> students;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? institutionFilter;
  final String? boardingPointFilter;

  StudentsState({
    this.students = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.institutionFilter,
    this.boardingPointFilter,
  });

  StudentsState copyWith({
    List<Student>? students,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? institutionFilter,
    String? boardingPointFilter,
  }) {
    return StudentsState(
      students: students ?? this.students,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      institutionFilter: institutionFilter ?? this.institutionFilter,
      boardingPointFilter: boardingPointFilter ?? this.boardingPointFilter,
    );
  }

  List<Student> get filteredStudents {
    var result = students;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((s) =>
        s.rollNo.toLowerCase().contains(query) ||
        s.name.toLowerCase().contains(query) ||
        s.institution.toLowerCase().contains(query) ||
        s.boardingPoint.toLowerCase().contains(query),
      ).toList();
    }
    if (institutionFilter != null && institutionFilter!.isNotEmpty) {
      result = result.where((s) => s.institution == institutionFilter).toList();
    }
    if (boardingPointFilter != null && boardingPointFilter!.isNotEmpty) {
      result = result.where((s) => s.boardingPoint == boardingPointFilter).toList();
    }
    return result;
  }

  List<String> get institutions {
    final set = <String>{};
    for (final s in students) {
      final inst = s.institution;
      if (inst.isNotEmpty) set.add(inst);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get boardingPoints {
    final set = <String>{};
    for (final s in students) {
      final bp = s.boardingPoint;
      if (bp.isNotEmpty) set.add(bp);
    }
    final list = set.toList()..sort();
    return list;
  }
}

class StudentsNotifier extends StateNotifier<StudentsState> {
  final StudentRepository _repository;

  StudentsNotifier(this._repository) : super(StudentsState());

  Future<void> loadStudents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final students = await _repository.getAll();
      state = state.copyWith(students: students, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> addStudent({
    required String rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
  }) async {
    final normalizedRollNo = rollNo.trim().toUpperCase();
    try {
      await _repository.insert(
        rollNo: normalizedRollNo,
        name: name.trim(),
        institution: institution.trim(),
        boardingPoint: boardingPoint.trim(),
      );
      await loadStudents();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> editStudent({
    required int id,
    required String name,
    required String institution,
    required String boardingPoint,
  }) async {
    try {
      await _repository.update(
        id: id,
        name: name.trim(),
        institution: institution.trim(),
        boardingPoint: boardingPoint.trim(),
      );
      await loadStudents();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> deleteStudent(int id) async {
    try {
      await _repository.delete(id);
      await loadStudents();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setInstitutionFilter(String? value) {
    state = state.copyWith(institutionFilter: value);
  }

  void setBoardingPointFilter(String? value) {
    state = state.copyWith(boardingPointFilter: value);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      institutionFilter: null,
      boardingPointFilter: null,
    );
  }
}