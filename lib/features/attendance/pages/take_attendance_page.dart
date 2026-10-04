import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  AttendanceFilter _filter = AttendanceFilter.all;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoaded) {
        _hasLoaded = true;
        ref
            .read(attendanceControllerProvider.notifier)
            .load(forDate: DateTime.now());
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
    final state = ref.read(attendanceControllerProvider);
    if (!state.isActive) return;
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
        final text = '${entry.student.rollNo} ${entry.student.name}'
            .toLowerCase();
        if (!text.contains(query)) continue;
      }
      filtered.add(entry);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AttendanceState>(attendanceControllerProvider, (previous, next) {
      if (next.lastOutcome != null &&
          (next.lastOutcome != previous?.lastOutcome ||
              next.lastBarcode != previous?.lastBarcode ||
              next.lastRecord != previous?.lastRecord)) {
        switch (next.lastOutcome!) {
          case AttendanceScanOutcome.marked:
            HapticFeedback.mediumImpact();
          case AttendanceScanOutcome.alreadyPresent:
            HapticFeedback.selectionClick();
          case AttendanceScanOutcome.notFound:
          case AttendanceScanOutcome.ambiguous:
            HapticFeedback.heavyImpact();
        }
      }
    });

    final state = ref.watch(attendanceControllerProvider);
    final notifier = ref.read(attendanceControllerProvider.notifier);
    final theme = Theme.of(context);
    final roster = _filteredRoster(state.roster);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.phase == AttendancePhase.active
              ? 'Attendance • ${state.tripType.label}'
              : 'Take Attendance',
        ),
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
                    Icon(
                      Icons.error,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _CameraSection(
            controller: _scanner,
            isActive: state.isActive,
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
                            value: AttendanceFilter.all,
                            label: Text('All'),
                          ),
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
    required this.isActive,
    required this.onDetect,
    required this.onToggleTorch,
    required this.onFlipCamera,
  });

  final MobileScannerController controller;
  final bool isActive;
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
          if (!isActive)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_circle_outline, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Scanner paused (session inactive)',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: ValueListenableBuilder<TorchState>(
              valueListenable: controller.torchState,
              builder: (context, torchState, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool?>(
                      valueListenable: controller.hasTorchState,
                      builder: (context, hasTorch, _) => hasTorch == true
                          ? IconButton.filledTonal(
                              icon: Icon(
                                torchState == TorchState.on
                                    ? Icons.flashlight_on
                                    : Icons.flashlight_off,
                              ),
                              tooltip: 'Toggle torch',
                              onPressed: onToggleTorch,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.cameraswitch_outlined),
                      tooltip: 'Switch camera',
                      onPressed: onFlipCamera,
                    ),
                  ],
                );
              },
            ),
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
    // A start, resume or finish is in flight. Showing the spinner replaces the
    // button so a second tap has nothing to hit.
    if (state.isSessionBusy) {
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
          child: Text('Resume ${state.tripType.label} Session'),
        );
      }
      if (state.needsNewSession) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => notifier.startSession(),
              child: Text('Start ${state.tripType.label} Session'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<TripType>(
              tooltip: 'Select Trip',
              initialValue: state.tripType,
              onSelected: (trip) => notifier.selectTrip(trip),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: TripType.morning,
                  child: Text('Morning Trip'),
                ),
                const PopupMenuItem(
                  value: TripType.evening,
                  child: Text('Evening Trip'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.tripType == TripType.morning
                          ? Icons.wb_sunny_outlined
                          : Icons.nights_stay_outlined,
                      size: 20,
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return const Text('No students in roster');
    }
    if (state.phase == AttendancePhase.active) {
      return FilledButton(
        onPressed: () => notifier.finishSession(),
        child: Text('Finish (${state.tripType.label})'),
      );
    }
    if (state.phase == AttendancePhase.finished) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => notifier.startSession(),
            child: Text('Start ${state.tripType.label} Session'),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.load(forDate: DateTime.now()),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
