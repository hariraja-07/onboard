import '../../../../core/database/database.dart';

/// The outcome of matching a scanned barcode against the student roster.
enum BarcodeMatchStatus {
  /// Exactly one student was identified.
  matched,

  /// No registered roll number appears in the scanned value.
  notFound,

  /// More than one registered roll number appears in the scanned value, so the
  /// intended student cannot be determined without a human decision.
  ambiguous,
}

/// The result of matching one scanned barcode.
///
/// [barcode] is always the value exactly as it arrived from the scanner — the
/// trimmed/upper-cased form used for matching is never written back over it, so
/// the record of what was physically scanned is preserved for auditing.
class BarcodeMatchResult {
  const BarcodeMatchResult({
    required this.barcode,
    required this.status,
    this.student,
    this.candidates = const [],
  });

  /// A barcode that identified exactly one student.
  const BarcodeMatchResult.matched({
    required String barcode,
    required Student student,
  }) : this(barcode: barcode, status: BarcodeMatchStatus.matched, student: student);

  /// A barcode containing no registered roll number.
  const BarcodeMatchResult.notFound({required String barcode})
      : this(barcode: barcode, status: BarcodeMatchStatus.notFound);

  /// A barcode containing more than one registered roll number.
  const BarcodeMatchResult.ambiguous({
    required String barcode,
    required List<Student> candidates,
  }) : this(
          barcode: barcode,
          status: BarcodeMatchStatus.ambiguous,
          candidates: candidates,
        );

  /// The scanned value, unmodified.
  final String barcode;

  final BarcodeMatchStatus status;

  /// The identified student. Non-null exactly when [status] is
  /// [BarcodeMatchStatus.matched].
  final Student? student;

  /// Every student whose roll number appears in [barcode]. Holds more than one
  /// entry exactly when [status] is [BarcodeMatchStatus.ambiguous].
  final List<Student> candidates;

  bool get isMatched => status == BarcodeMatchStatus.matched;

  bool get isNotFound => status == BarcodeMatchStatus.notFound;

  bool get isAmbiguous => status == BarcodeMatchStatus.ambiguous;

  @override
  String toString() =>
      'BarcodeMatchResult(${status.name}, barcode: "$barcode", '
      '${isMatched ? 'student: ${student?.rollNo}' : 'candidates: ${candidates.length}'})';
}