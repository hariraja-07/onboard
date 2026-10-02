import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/student_repository.dart';
import 'barcode_models.dart';
import 'barcode_service.dart';

/// State for the barcode scanner screen.
class BarcodeState {
  const BarcodeState({
    this.students = const [],
    this.isLoading = false,
    this.error,
    this.lastResult,
  });

  /// The roster currently available for matching.
  final List<Student> students;

  final bool isLoading;

  /// Set when the roster could not be read, or when a scan arrived before the
  /// roster had loaded.
  final String? error;

  /// The most recent match attempt, whatever its outcome.
  final BarcodeMatchResult? lastResult;

  /// Nothing can be matched against an empty roster, so the UI uses this to
  /// avoid showing a misleading "Student Not Found".
  bool get canMatch => students.isNotEmpty && error == null;
}

final barcodeControllerProvider = StateNotifierProvider.autoDispose<
    BarcodeController, BarcodeState>((ref) {
  return BarcodeController(
    studentRepository: ref.watch(studentRepositoryProvider),
    service: const BarcodeService(),
  );
});

/// Loads the roster and resolves scanned barcodes against it.
///
/// The matching rules themselves live in [BarcodeService] and know nothing
/// about this class; the controller only fetches students and holds the most
/// recent result for the UI to render.
class BarcodeController extends StateNotifier<BarcodeState> {
  BarcodeController({
    required StudentRepository studentRepository,
    required BarcodeService service,
    Duration scanCooldown = defaultScanCooldown,
    DateTime Function()? clock,
  })  : _students = studentRepository,
        _service = service,
        _scanCooldown = scanCooldown,
        _clock = clock ?? DateTime.now,
        super(const BarcodeState());

  /// How long the same barcode is ignored after a camera scan.
  static const Duration defaultScanCooldown = Duration(seconds: 2);

  final StudentRepository _students;
  final BarcodeService _service;
  final Duration _scanCooldown;
  final DateTime Function() _clock;

  String? _lastScannedBarcode;
  DateTime? _lastScanAt;

  /// Reads the roster. Safe to call again to pick up an Excel import.
  Future<void> loadStudents() async {
    // Built explicitly rather than with copyWith: `error` has to be able to go
    // back to null, which a `??`-based copyWith can never express.
    state = BarcodeState(students: state.students, isLoading: true);
    try {
      final students = await _students.getAll();
      state = BarcodeState(students: students);
    } catch (error) {
      state = BarcodeState(
        students: state.students,
        error: 'Could not load students.\n$error',
      );
    }
  }

  /// Matches a barcode that was typed in by hand.
  ///
  /// Never rate limited: re-testing the same value has to keep working.
  BarcodeMatchResult submitBarcode(String rawBarcode) {
    final result = _service.match(rawBarcode, state.students);
    state = BarcodeState(
      students: state.students,
      isLoading: state.isLoading,
      error: state.error,
      lastResult: result,
    );
    return result;
  }

  /// Matches a barcode that came from the camera.
  ///
  /// A card held in front of the lens produces a detection on every frame, so
  /// an unchanged value is swallowed for [scanCooldown]. Without this the UI
  /// would re-render the same result several times a second.
  void onBarcodeScanned(String rawBarcode) {
    final now = _clock();
    final previousAt = _lastScanAt;
    if (rawBarcode == _lastScannedBarcode &&
        previousAt != null &&
        now.difference(previousAt) < _scanCooldown) {
      return;
    }
    _lastScannedBarcode = rawBarcode;
    _lastScanAt = now;
    submitBarcode(rawBarcode);
  }

  /// Clears the current result, e.g. when the operator scans the next card.
  void clearResult() {
    _lastScannedBarcode = null;
    _lastScanAt = null;
    state = BarcodeState(
      students: state.students,
      isLoading: state.isLoading,
      error: state.error,
    );
  }
}