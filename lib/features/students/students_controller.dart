import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/student_repository.dart';

final studentsProvider = StateNotifierProvider<StudentsNotifier, StudentsState>(
  (ref) {
    return StudentsNotifier(ref.watch(studentRepositoryProvider));
  },
);

class StudentsState {
  final List<Student> students;
  final bool isLoading;
  final String? error;
  final String? actionMessage;
  final String? actionError;
  final String searchQuery;
  final String? institutionFilter;
  final String? boardingPointFilter;

  StudentsState({
    this.students = const [],
    this.isLoading = false,
    this.error,
    this.actionMessage,
    this.actionError,
    this.searchQuery = '',
    this.institutionFilter,
    this.boardingPointFilter,
  });

  /// Distinguishes "argument not supplied" from "argument supplied as null".
  ///
  /// A plain `String?` parameter plus `?? this.error` cannot do that: passing
  /// `null` is indistinguishable from omitting the argument, so the old error
  /// was always kept. That made [error] impossible to clear and wedged the
  /// Students screen on its error view, because clearing only ever happened
  /// on the load path that was itself broken. The same trap applied to both
  /// filter fields, so `clearFilters()` silently kept them.
  static const Object _unset = Object();

  StudentsState copyWith({
    List<Student>? students,
    bool? isLoading,
    Object? error = _unset,
    Object? actionMessage = _unset,
    Object? actionError = _unset,
    String? searchQuery,
    Object? institutionFilter = _unset,
    Object? boardingPointFilter = _unset,
  }) {
    return StudentsState(
      students: students ?? this.students,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      actionMessage: identical(actionMessage, _unset)
          ? this.actionMessage
          : actionMessage as String?,
      actionError: identical(actionError, _unset)
          ? this.actionError
          : actionError as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      institutionFilter: identical(institutionFilter, _unset)
          ? this.institutionFilter
          : institutionFilter as String?,
      boardingPointFilter: identical(boardingPointFilter, _unset)
          ? this.boardingPointFilter
          : boardingPointFilter as String?,
    );
  }

  List<Student> get filteredStudents {
    var result = students;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result
          .where(
            (s) =>
                s.rollNo.toLowerCase().contains(query) ||
                s.name.toLowerCase().contains(query) ||
                s.institution.toLowerCase().contains(query) ||
                s.boardingPoint.toLowerCase().contains(query),
          )
          .toList();
    }
    if (institutionFilter != null && institutionFilter!.isNotEmpty) {
      result = result.where((s) => s.institution == institutionFilter).toList();
    }
    if (boardingPointFilter != null && boardingPointFilter!.isNotEmpty) {
      result = result
          .where((s) => s.boardingPoint == boardingPointFilter)
          .toList();
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

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Roll numbers are the identity key, so they are trimmed, whitespace
  /// collapsed and upper-cased. This mirrors
  /// [ExcelImportService.normaliseRollNo] so a student added by hand and the
  /// same student imported from a sheet cannot end up stored differently.
  String _normaliseRollNo(String raw) =>
      raw.replaceAll(_whitespace, ' ').trim().toUpperCase();

  /// Turns a repository failure into wording an operator can act on.
  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('UNIQUE')) {
      return 'A student with this roll number already exists.';
    }
    return 'Something went wrong. Please try again.';
  }

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
    try {
      await _repository.insert(
        rollNo: _normaliseRollNo(rollNo),
        name: name.trim(),
        institution: institution.trim(),
        boardingPoint: boardingPoint.trim(),
      );
      await loadStudents();
      state = state.copyWith(
        actionMessage: 'Student added.',
        actionError: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(actionError: _friendlyError(e));
      return false;
    }
  }

  Future<bool> editStudent({
    required int id,
    String? rollNo,
    required String name,
    required String institution,
    required String boardingPoint,
  }) async {
    try {
      await _repository.update(
        id: id,
        rollNo: rollNo == null ? null : _normaliseRollNo(rollNo),
        name: name.trim(),
        institution: institution.trim(),
        boardingPoint: boardingPoint.trim(),
      );
      await loadStudents();
      state = state.copyWith(
        actionMessage: 'Student updated.',
        actionError: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(actionError: _friendlyError(e));
      return false;
    }
  }

  Future<bool> deleteStudent(int id) async {
    try {
      await _repository.delete(id);
      await loadStudents();
      state = state.copyWith(
        actionMessage: 'Student deleted.',
        actionError: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(actionError: _friendlyError(e));
      return false;
    }
  }

  /// Clears a pending success or failure banner once it has been shown.
  void clearActionFeedback() {
    state = state.copyWith(actionMessage: null, actionError: null);
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
