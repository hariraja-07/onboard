import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/database/repositories/student_repository.dart';
import 'package:onboard/features/attendance/barcode/barcode_controller.dart';
import 'package:onboard/features/attendance/barcode/barcode_models.dart';
import 'package:onboard/features/attendance/barcode/barcode_service.dart';

void main() {
  late AppDatabase db;
  late StudentRepository repository;
  var now = DateTime.utc(2026, 10, 2, 9);

  setUp(() {
    now = DateTime.utc(2026, 10, 2, 9);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = StudentRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedStudents(List<String> rollNos) async {
    for (final rollNo in rollNos) {
      await repository.insert(
        rollNo: rollNo,
        name: 'Student $rollNo',
        institution: 'Springfield College',
        boardingPoint: 'North Gate',
      );
    }
  }

  BarcodeController controller({
    Duration cooldown = const Duration(seconds: 2),
  }) => BarcodeController(
    studentRepository: repository,
    service: const BarcodeService(),
    scanCooldown: cooldown,
    clock: () => now,
  );

  group('roster loading', () {
    test('loads registered students for matching', () async {
      await seedStudents(['24BMR016', '25BMR017']);
      final notifier = controller();

      await notifier.loadStudents();

      expect(
        notifier.state.students.map((s) => s.rollNo),
        containsAll(<String>['24BMR016', '25BMR017']),
      );
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.canMatch, isTrue);
    });

    test('reports an empty roster rather than claiming success', () async {
      final notifier = controller();

      await notifier.loadStudents();

      expect(notifier.state.students, isEmpty);
      expect(notifier.state.canMatch, isFalse);
    });

    test('picks up a roster imported after the screen first opened', () async {
      final notifier = controller();
      await notifier.loadStudents();
      expect(notifier.state.students, isEmpty);

      await seedStudents(['24BMR016']);
      await notifier.loadStudents();

      expect(notifier.state.canMatch, isTrue);
    });
  });

  group('manual entry', () {
    test('matches a typed barcode and records the result', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      final result = notifier.submitBarcode('732924BMR016');

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
      expect(notifier.state.lastResult, same(result));
    });

    test('re-testing the same barcode always re-matches', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      expect(notifier.submitBarcode('732924BMR016').isMatched, isTrue);
      expect(notifier.submitBarcode('732924BMR016').isMatched, isTrue);
      expect(notifier.state.lastResult?.isMatched, isTrue);
    });

    test('scans against an empty roster report not found', () async {
      final notifier = controller();
      await notifier.loadStudents();

      final result = notifier.submitBarcode('732924BMR016');

      expect(result.isNotFound, isTrue);
    });
  });

  group('camera scan cooldown', () {
    test('ignores a repeat of the same card inside the cooldown', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      notifier.onBarcodeScanned('732924BMR016');
      final resultAfterFirst = notifier.state.lastResult;
      now = now.add(const Duration(milliseconds: 900));
      notifier.onBarcodeScanned('732924BMR016');

      expect(notifier.state.lastResult, same(resultAfterFirst));
    });

    test('accepts the same card again once the cooldown has passed', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      notifier.onBarcodeScanned('732924BMR016');
      final first = notifier.state.lastResult;
      now = now.add(const Duration(seconds: 3));
      notifier.onBarcodeScanned('732924BMR016');

      expect(notifier.state.lastResult, isNot(same(first)));
      expect(notifier.state.lastResult?.isMatched, isTrue);
    });

    test('a different card is always accepted', () async {
      await seedStudents(['24BMR016', '25BMR017']);
      final notifier = controller();
      await notifier.loadStudents();

      notifier.onBarcodeScanned('732924BMR016');
      notifier.onBarcodeScanned('732925BMR017');

      expect(notifier.state.lastResult?.student?.rollNo, '25BMR017');
    });

    test('clearing the result lets the same card be scanned again', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      notifier.onBarcodeScanned('732924BMR016');
      notifier.clearResult();
      expect(notifier.state.lastResult, isNull);

      notifier.onBarcodeScanned('732924BMR016');

      expect(notifier.state.lastResult?.isMatched, isTrue);
    });
  });

  group('result shape', () {
    test(
      'an ambiguous barcode exposes every candidate from the database',
      () async {
        await seedStudents(['24BMR016', 'BMR016']);
        final notifier = controller();
        await notifier.loadStudents();

        final result = notifier.submitBarcode('732924BMR016');

        expect(result.status, BarcodeMatchStatus.ambiguous);
        expect(
          result.candidates.map((s) => s.rollNo),
          containsAll(<String>['24BMR016', 'BMR016']),
        );
      },
    );

    test('a not-found barcode still reports the scanned value', () async {
      await seedStudents(['24BMR016']);
      final notifier = controller();
      await notifier.loadStudents();

      final result = notifier.submitBarcode(' 9999unknown ');

      expect(result.barcode, ' 9999unknown ');
    });
  });
}
