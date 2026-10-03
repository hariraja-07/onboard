import '../../../core/database/database.dart';
import 'barcode_models.dart';

/// Maps a raw scanned barcode onto a registered student.
///
/// Deliberately free of Flutter, Riverpod and widget imports so the matching
/// rules can be unit tested directly and reasoned about on their own. The
/// roster is supplied by the caller rather than fetched here, which keeps the
/// service a pure function of its arguments.
///
/// No part of the barcode is treated as special. A bus operator's card may
/// carry any institutional prefix, serial padding or separator, so the roll
/// number is looked for *inside* the scanned value rather than the scanned
/// value being sliced at a hardcoded offset.
class BarcodeService {
  const BarcodeService();

  /// Trims and upper-cases a scanned value or a stored roll number so the two
  /// can be compared. Internal whitespace is left alone: it is meaningful to
  /// an operator and removing it would merge distinct roll numbers.
  static String normalise(String value) => value.trim().toUpperCase();

  /// Resolves [rawBarcode] against [students].
  ///
  /// The comparison runs in two passes, cheapest first:
  ///
  /// 1. An exact match on a normalised roll number.
  /// 2. Otherwise every registered roll number that occurs *within* the
  ///    barcode.
  ///
  /// The second pass is deliberately permissive about what counts as a
  /// candidate: if two roll numbers both appear in the scanned value the
  /// result is [BarcodeMatchStatus.ambiguous] rather than a guess. Choosing
  /// silently would mark the wrong student present, which is worse than
  /// asking the operator to hold the card differently.
  BarcodeMatchResult match(String rawBarcode, List<Student> students) {
    final barcode = normalise(rawBarcode);

    if (barcode.isEmpty) {
      return BarcodeMatchResult.notFound(barcode: rawBarcode);
    }

    // Normalised roll number for each student, in the same order as `students`.
    final rollNos = [for (final student in students) normalise(student.rollNo)];

    // Pass 1: an exact match. Roll numbers are unique in the database, so at
    // most one student can match here; scanning in order also means a
    // hand-built roster that repeats a roll number resolves deterministically
    // instead of throwing.
    for (var i = 0; i < rollNos.length; i++) {
      if (rollNos[i] == barcode) {
        return BarcodeMatchResult.matched(
          barcode: rawBarcode,
          student: students[i],
        );
      }
    }

    // Pass 2: every registered roll number occurring within the barcode.
    final contained = <Student>[];
    for (var i = 0; i < rollNos.length; i++) {
      // An empty roll number is contained in every barcode, which would make
      // any scan ambiguous.
      if (rollNos[i].isNotEmpty && barcode.contains(rollNos[i])) {
        contained.add(students[i]);
      }
    }

    if (contained.length == 1) {
      return BarcodeMatchResult.matched(
        barcode: rawBarcode,
        student: contained.single,
      );
    }
    if (contained.isEmpty) {
      return BarcodeMatchResult.notFound(barcode: rawBarcode);
    }
    return BarcodeMatchResult.ambiguous(
      barcode: rawBarcode,
      candidates: contained,
    );
  }
}
