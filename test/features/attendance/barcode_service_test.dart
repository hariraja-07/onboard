import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/features/attendance/barcode/barcode_models.dart';
import 'package:onboard/features/attendance/barcode/barcode_service.dart';

/// Builds a roster entry. Roll numbers are the only field the matcher reads, so
/// the rest is filled with plausible but arbitrary values.
Student student(String rollNo, {String? name}) => Student(
      id: rollNo.hashCode,
      rollNo: rollNo,
      name: name ?? 'Student $rollNo',
      institution: 'Springfield College',
      boardingPoint: 'North Gate',
      createdAt: DateTime.utc(2026, 1, 1),
    );

/// The roster described in the feature request.
List<Student> roster() => [
      student('24BMR016', name: 'Asha Rao'),
      student('25BMR017', name: 'Bilal Khan'),
      student('23BMR015', name: 'Chitra Devi'),
    ];

void main() {
  const service = BarcodeService();
  final students = roster();

  group('exact roll number match', () {
    test('matches a barcode that is exactly the roll number', () {
      final result = service.match('24BMR016', students);

      expect(result.status, BarcodeMatchStatus.matched);
      expect(result.student?.rollNo, '24BMR016');
      expect(result.student?.name, 'Asha Rao');
    });

    test('matches a lower-case barcode', () {
      final result = service.match('24bmr016', students);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });

    test('matches a barcode padded with surrounding whitespace', () {
      final result = service.match('  24BMR016  ', students);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });

    test('matches when the stored roll number has stray whitespace', () {
      final result = service.match('24BMR016', [student(' 24bmr016 ')]);

      expect(result.isMatched, isTrue);
    });

    test('an exact match wins even when another roll number is contained', () {
      final result = service.match('24BMR016', [
        student('24BMR016'),
        student('BMR016'),
      ]);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });
  });

  group('roll number contained in the barcode', () {
    test('matches the documented prefixed barcode', () {
      final result = service.match('732924BMR016', students);

      expect(result.status, BarcodeMatchStatus.matched);
      expect(result.student?.rollNo, '24BMR016');
      expect(result.student?.name, 'Asha Rao');
    });

    test('finds a roll number at the start of the barcode', () {
      final result = service.match('24BMR016X', students);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });

    test('finds a roll number surrounded by separators', () {
      final result = service.match('ID-7329/24BMR016/END', students);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });

    test('does not special-case any particular prefix', () {
      // Guards the requirement that "7329" is never hardcoded: an unrelated
      // prefix, and a longer one, must resolve to the same student.
      for (final barcode in [
        '999924BMR016',
        '000000000732924BMR016',
        'ABC24BMR016',
      ]) {
        final result = service.match(barcode, students);
        expect(result.isMatched, isTrue, reason: 'failed for "$barcode"');
        expect(result.student?.rollNo, '24BMR016');
      }
    });

    test('matches every student in the roster through their own card', () {
      for (final target in students) {
        final result = service.match('7329${target.rollNo}', students);
        expect(result.isMatched, isTrue, reason: 'failed for ${target.rollNo}');
        expect(result.student?.rollNo, target.rollNo);
      }
    });
  });

  group('no student matches', () {
    test('reports not found for an unknown roll number', () {
      final result = service.match('732999BMR999', students);

      expect(result.status, BarcodeMatchStatus.notFound);
      expect(result.student, isNull);
      expect(result.candidates, isEmpty);
    });

    test('reports not found for an empty roster', () {
      final result = service.match('732924BMR016', []);

      expect(result.isNotFound, isTrue);
    });

    test('reports not found for a blank barcode', () {
      expect(service.match('', students).isNotFound, isTrue);
      expect(service.match('    ', students).isNotFound, isTrue);
    });

    test('reports not found when the barcode is shorter than every roll number',
        () {
      final result = service.match('7329', students);

      expect(result.isNotFound, isTrue);
    });

    test('a blank roll number does not make every barcode ambiguous', () {
      final result = service.match('732924BMR016', [
        student(''),
        student('24BMR016'),
      ]);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });
  });

  group('multiple students could match', () {
    test('reports ambiguous and lists every candidate', () {
      final result = service.match('732924BMR016', [
        student('24BMR016'),
        student('BMR016'),
      ]);

      expect(result.status, BarcodeMatchStatus.ambiguous);
      expect(result.student, isNull);
      expect(
        result.candidates.map((s) => s.rollNo),
        containsAll(<String>['24BMR016', 'BMR016']),
      );
      expect(result.candidates, hasLength(2));
    });

    test('three overlapping roll numbers are all reported', () {
      final result = service.match('732924BMR016', [
        student('24BMR016'),
        student('BMR016'),
        student('016'),
      ]);

      expect(result.isAmbiguous, isTrue);
      expect(result.candidates, hasLength(3));
    });

    test('a single candidate among several non-matching students is matched', () {
      final result = service.match('732924BMR016', [
        student('99ZZZ001'),
        student('24BMR016'),
        student('88QQQ002'),
      ]);

      expect(result.isMatched, isTrue);
      expect(result.student?.rollNo, '24BMR016');
    });
  });

  group('the original scanned value is preserved', () {
    test('keeps the barcode exactly as scanned', () {
      final result = service.match(' 732924bmr016 ', students);

      expect(result.barcode, ' 732924bmr016 ');
    });

    test('keeps the barcode for a not-found result', () {
      final result = service.match(' unknown-card ', students);

      expect(result.barcode, ' unknown-card ');
    });

    test('keeps the barcode for an ambiguous result', () {
      final result = service.match(' 732924BMR016 ', [
        student('24BMR016'),
        student('BMR016'),
      ]);

      expect(result.barcode, ' 732924BMR016 ');
    });

    test('keeps the barcode for a blank scan', () {
      expect(service.match('  ', students).barcode, '  ');
    });
  });

  group('normalisation', () {
    test('trims and upper-cases', () {
      expect(BarcodeService.normalise('  24bmr016 '), '24BMR016');
    });

    test('leaves internal whitespace intact', () {
      // Collapsing internal spaces would merge distinct roll numbers, which is
      // why only the ends are trimmed.
      expect(BarcodeService.normalise(' 24 bmr 016 '), '24 BMR 016');
    });
  });
}