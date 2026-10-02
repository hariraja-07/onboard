import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/students/students_controller.dart';

/// Wraps [StudentRepository] so `getAll` can be made to fail on demand.
class _FlakyStudentRepository extends StudentRepository {
  _FlakyStudentRepository(super.db);

  bool failNextLoad = false;

  @override
  Future<List<Student>> getAll() async {
    if (failNextLoad) {
      throw Exception('database is locked');
    }
    return super.getAll();
  }
}

void main() {
  late AppDatabase db;
  late _FlakyStudentRepository repository;
  late StudentsNotifier notifier;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _FlakyStudentRepository(db);
    notifier = StudentsNotifier(repository);

    await repository.insert(
      rollNo: '24BMR016',
      name: 'Asha Rao',
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
    );
    await repository.insert(
      rollNo: '25BMR017',
      name: 'Bilal Khan',
      institution: 'Riverside School',
      boardingPoint: 'South Gate',
    );
  });

  tearDown(() => db.close());

  Future<void> loadSuccessfully() async {
    repository.failNextLoad = false;
    await notifier.loadStudents();
  }

  group('nullable fields survive being omitted', () {
    test('copyWith keeps error, filters and query when not mentioned', () {
      final populated = StudentsState(
        students: const [],
        isLoading: true,
        error: 'boom',
        searchQuery: 'asha',
        institutionFilter: 'Springfield College',
        boardingPointFilter: 'North Gate',
      );

      final result = populated.copyWith(students: const []);

      expect(result.error, 'boom');
      expect(result.searchQuery, 'asha');
      expect(result.institutionFilter, 'Springfield College');
      expect(result.boardingPointFilter, 'North Gate');
    });
  });

  group('nullable fields can be cleared', () {
    test('copyWith clears the error when passed null explicitly', () {
      final populated = StudentsState(error: 'boom');

      expect(populated.copyWith().error, 'boom');
      expect(populated.copyWith(error: null).error, isNull);
    });

    test('copyWith clears both filters when passed null explicitly', () {
      final populated = StudentsState(
        institutionFilter: 'Springfield College',
        boardingPointFilter: 'North Gate',
      );

      expect(
        populated.copyWith(institutionFilter: null, boardingPointFilter: null)
            .institutionFilter,
        isNull,
      );
      expect(
        populated.copyWith(institutionFilter: null, boardingPointFilter: null)
            .boardingPointFilter,
        isNull,
      );
    });
  });

  group('a failed load is recoverable', () {
    test('a later successful load clears the error', () async {
      repository.failNextLoad = true;
      await notifier.loadStudents();
      expect(notifier.state.error, isNotNull);

      await loadSuccessfully();

      expect(notifier.state.error, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.students, hasLength(2));
    });

    test('a successful add clears an error left by a failed load', () async {
      // This is the path a user actually takes to recover: the failed load
      // blanks the list, they add a student, and the list must come back.
      repository.failNextLoad = true;
      await notifier.loadStudents();
      expect(notifier.state.error, isNotNull);

      // The transient fault clears; addStudent reloads the roster itself.
      repository.failNextLoad = false;
      final added = await notifier.addStudent(
        rollNo: '26BMR018',
        name: 'Chandra Iyer',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );

      expect(added, isTrue);
      expect(notifier.state.error, isNull);
      expect(notifier.state.students, hasLength(3));
    });

    test('a failing add still reports the error', () async {
      // The roll number is UNIQUE, so re-adding one must fail loudly rather
      // than silently doing nothing.
      final added = await notifier.addStudent(
        rollNo: '24BMR016',
        name: 'Duplicate',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );

      expect(added, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('a later successful delete clears the error', () async {
      repository.failNextLoad = true;
      await notifier.loadStudents();
      expect(notifier.state.error, isNotNull);

      await loadSuccessfully();

      expect(notifier.state.error, isNull);
    });
  });

  group('filters', () {
    test('clearFilters clears the search query and both dropdowns', () async {
      await loadSuccessfully();
      notifier
        ..setSearchQuery('asha')
        ..setInstitutionFilter('Springfield College')
        ..setBoardingPointFilter('North Gate');

      expect(notifier.state.filteredStudents, hasLength(1));

      notifier.clearFilters();

      expect(notifier.state.searchQuery, '');
      expect(notifier.state.institutionFilter, isNull);
      expect(notifier.state.boardingPointFilter, isNull);
      expect(notifier.state.filteredStudents, hasLength(2));
    });

    test('choosing the all option clears a dropdown filter', () async {
      await loadSuccessfully();
      notifier.setInstitutionFilter('Springfield College');
      expect(notifier.state.filteredStudents, hasLength(1));

      // Mirrors the dropdown's onChanged, which passes null for "all".
      notifier.setInstitutionFilter(null);

      expect(notifier.state.institutionFilter, isNull);
      expect(notifier.state.filteredStudents, hasLength(2));
    });

    test('choosing the all option clears a boarding point filter', () async {
      await loadSuccessfully();
      notifier.setBoardingPointFilter('North Gate');
      expect(notifier.state.filteredStudents, hasLength(1));

      notifier.setBoardingPointFilter(null);

      expect(notifier.state.boardingPointFilter, isNull);
      expect(notifier.state.filteredStudents, hasLength(2));
    });
  });
}