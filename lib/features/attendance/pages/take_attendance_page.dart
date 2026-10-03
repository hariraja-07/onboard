import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../attendance_controller.dart';
import '../models/attendance_models.dart';
import '../widgets/attendance_result_banner.dart';
import '../widgets/attendance_roster_table.dart';

/// Primary Take Attendance screen.
///
/// Camera is pinned outside the scroll view for continuous scanning.
/// Roster is displayed in a phone-first layout; text search filters by
/// roll number and name only.
class TakeAttendancePage extends ConsumerStatefulWidget {
  const TakeAttendancePage({super.key});

  @override
  ConsumerState<TakeAttendancePage> createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends ConsumerState<TakeAttendancePage> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    detectionTimeoutMs: 250,
  );

  final TextEditingController _search = TextEditingController();
  AttendanceFilter _filter = AttendanceFilter.present;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoaded) {
        _hasLoaded = true;
        ref.read(attendanceControllerProvider.notifier).load(forDate: DateTime.now());
      }
    });
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        ref.read(attendanceControllerProvider.notifier).onBarcodeScanned(raw);
        return;
      }
    }
  }

  void _toggleTorch() {
    _scanner.toggleTorch();
    setState(() {});
  }

  void _flipCamera() {
    _scanner.switchCamera();
    setState(() {});
  }

  List<StudentAttendance> _filteredRoster(List<StudentAttendance> roster) {
    final query = _search.text.trim().toLowerCase();
    final filtered = <StudentAttendance>[];
    for (final entry in roster) {
      final matchesFilter = switch (_filter) {
        AttendanceFilter.present => entry.isPresent,
        AttendanceFilter.absent => !entry.isPresent,
        AttendanceFilter.all => true,
      };
      if (!matchesFilter) continue;
      if (query.isNotEmpty) {
        final text = '${entry.student.rollNo} ${entry.student.name}'.toLowerCase();
        if (!text.contains(query)) continue;
      }
      filtered.add(entry);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);
    final notifier = ref.read(attendanceControllerProvider.notifier);
    final theme = Theme.of(context);
    final roster = _filteredRoster(state.roster);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Manual test screen',
            onPressed: () => context.push('/attendance/debug'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _CameraSection(
            controller: _scanner,
            onDetect: _onDetect,
            onToggleTorch: _toggleTorch,
            onFlipCamera: _flipCamera,
          ),
          const SizedBox(height: 8),
          AttendanceResultBanner(state: state),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<AttendanceFilter>(
                        segments: const [
                          ButtonSegment(
                            value: AttendanceFilter.present,
                            label: Text('Present'),
                          ),
                          ButtonSegment(
                            value: AttendanceFilter.absent,
                            label: Text('Absent'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (s) {
                          if (s.isNotEmpty) {
                            setState(() => _filter = s.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search roll no or name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SessionActions(state: state, notifier: notifier),
                    Text(
                      '${state.presentCount}/${state.totalCount} • ${state.attendancePercent.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: AttendanceRosterTable(
              state: state,
              filtered: roster,
              filter: _filter,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraSection extends StatelessWidget {
  const _CameraSection({
    required this.controller,
    required this.onDetect,
    required this.onToggleTorch,
    required this.onFlipCamera,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onToggleTorch;
  final VoidCallback onFlipCamera;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
            errorBuilder: (context, error, _) => _CameraError(error: error),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined),
            const SizedBox(height: 8),
            Text(error.errorCode.name),
            if (error.errorDetails?.message != null)
              Text(error.errorDetails!.message!)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _SessionActions extends StatelessWidget {
  const _SessionActions({required this.state, required this.notifier});

  final AttendanceState state;
  final AttendanceController notifier;

  @override
  Widget build(BuildContext context) {
    if (state.phase == AttendancePhase.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.phase == AttendancePhase.awaitingStart) {
      if (state.canResume) {
        return FilledButton.tonal(
          onPressed: () => notifier.resumeSession(),
          child: const Text('Resume Session'),
        );
      }
      if (state.needsNewSession) {
        return FilledButton(
          onPressed: () => notifier.startSession(),
          child: const Text('Start Session'),
        );
      }
      return const Text('No students in roster');
    }
    if (state.phase == AttendancePhase.active) {
      return FilledButton(
        onPressed: () => notifier.finishSession(),
        child: const Text('Finish'),
      );
    }
    if (state.phase == AttendancePhase.finished) {
      return const Text('Session finished');
    }
    return const SizedBox.shrink();
  }
}

