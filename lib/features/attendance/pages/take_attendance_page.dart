import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/spacing.dart';
import '../attendance_controller.dart';
import '../models/attendance_models.dart';
import '../widgets/attendance_result_banner.dart';
import '../widgets/attendance_roster_table.dart';

/// Whether the camera should be running.
///
/// Both conditions matter: the session has to accept scans, and this tab has to
/// be the visible one. The router is a [StatefulShellRoute] indexed stack, so
/// offstage branches stay mounted and their cameras keep running unless the tab
/// itself is taken into account.
bool shouldRunScanner({required bool isActive, required bool isTabVisible}) =>
    isActive && isTabVisible;

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

class _TakeAttendancePageState extends ConsumerState<TakeAttendancePage>
    with WidgetsBindingObserver {
  final MobileScannerController _scanner = MobileScannerController(
    // Continuous: every frame is analysed rather than the scanner going blind
    // for a timeout after each hit. Repeats are filtered natively before they
    // reach Dart, so the controller's own cooldown is only the second line of
    // defence. This trades a timeout for roughly seven times as many decoder
    // runs, which is only affordable alongside the single format below.
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    // ID cards carry a horizontal stripe. One format also keeps ML Kit on its
    // single-format path; if a card ever fails to read at all rather than
    // slowly, the symbology is a different one and this is the only line to
    // change: code39, ean13, upcA.
    formats: const [BarcodeFormat.code128],
    // The camera is driven from the session phase rather than by the widget's
    // own auto start, so that starting one implies stopping the other.
    autoStart: false,
  );

  final TextEditingController _search = TextEditingController();
  AttendanceFilter _filter = AttendanceFilter.all;
  bool _hasLoaded = false;

  /// Whether this tab is the selected shell branch.
  ///
  /// Read from [TickerMode] because go_router wraps every branch in
  /// `TickerMode(enabled: isActive)`, which makes the shell's own current index
  /// observable here without threading it through a provider.
  bool _isTabVisible = true;

  /// The camera state we have asked for, as opposed to the one the platform
  /// actually reached. Guards against redundant start/stop calls.
  bool _scannerShouldRun = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _isTabVisible) return;
    _isTabVisible = visible;
    unawaited(_syncScanner());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    // The scanner widget stops itself when the app leaves the foreground and
    // restarts itself when it comes back, which would revive a camera the
    // operator has paused or navigated away from. Our observer is registered
    // before the widget's, so re-asserting after the frame settles runs last.
    if (appState == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncScanner();
      });
    }
  }

  /// Brings the camera in line with the session phase and the visible tab.
  Future<void> _syncScanner() async {
    final shouldRun = shouldRunScanner(
      isActive: ref.read(attendanceControllerProvider).isActive,
      isTabVisible: _isTabVisible,
    );
    if (shouldRun == _scannerShouldRun) return;
    _scannerShouldRun = shouldRun;
    try {
      if (shouldRun) {
        await _scanner.start();
      } else {
        await _scanner.stop();
      }
    } on Exception {
      // start() and stop() raise MobileScannerException or PlatformException
      // when the camera is unavailable or permission is denied, and
      // MissingPluginException when there is no platform channel at all, which
      // is the case under widget tests. None of that can corrupt attendance:
      // _onDetect gates on isActive regardless of what the camera is doing.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _togglePause() {
    final notifier = ref.read(attendanceControllerProvider.notifier);
    if (ref.read(attendanceControllerProvider).isPaused) {
      notifier.resumeFromPause();
    } else {
      notifier.pauseSession();
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
      unawaited(_syncScanner());
      if (next.lastOutcome != null &&
          (next.lastOutcome != previous?.lastOutcome ||
              next.lastBarcode != previous?.lastBarcode ||
              next.lastRecord != previous?.lastRecord)) {
        switch (next.lastOutcome!) {
          case AttendanceScanOutcome.marked:
            HapticFeedback.mediumImpact();
            break;
          case AttendanceScanOutcome.alreadyPresent:
            // Re-presenting a card that is already marked is routine, and the
            // cooldown only holds for two seconds, so a student standing at the
            // desk would otherwise be buzzed at them over and over. Stays
            // silent; the roster row already shows them as present.
            break;
          case AttendanceScanOutcome.notFound:
          case AttendanceScanOutcome.ambiguous:
            HapticFeedback.heavyImpact();
            break;
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
          state.isSessionOpen
              ? 'Attendance • ${state.tripType.label}'
              : 'Take Attendance',
        ),
      ),
      // The three regions split the height explicitly instead of relying on
      // flex, which can only divide it by ratio: the preview gives height back
      // on a short screen, the controls take what they need up to a ceiling and
      // scroll past that, and the roster gets the rest.
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A small phone held in portrait, with the system text scale turned
          // up, cannot fit a full height preview, the controls and a usable
          // strip of roster at once. Giving the preview about a third of the
          // height is what keeps all three usable.
          const rosterFloor = 120.0;
          final previewHeight = (constraints.maxHeight * 0.30).clamp(
            96.0,
            220.0,
          );
          // 8 above the controls, 1 for the divider below them.
          final controlsCeiling = math.max(
            0.0,
            constraints.maxHeight - previewHeight - 9 - rosterFloor,
          );

          return Column(
            children: [
              if (state.error != null)
                Material(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: Insets.allMd,
                    child: Row(
                      children: [
                        Icon(
                          Icons.error,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: Insets.xs),
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
                maxHeight: previewHeight,
                isPaused: state.isPaused,
                isScanning: shouldRunScanner(
                  isActive: state.isActive,
                  isTabVisible: _isTabVisible,
                ),
                onDetect: _onDetect,
                onToggleTorch: _toggleTorch,
                onFlipCamera: _flipCamera,
                onTogglePause: _togglePause,
              ),
              const SizedBox(height: Insets.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: controlsCeiling),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AttendanceResultBanner(state: state),
                      const SizedBox(height: Insets.xs),
                      Padding(
                        padding: Insets.horizontalMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _search,
                              textInputAction: state.isActive
                                  ? TextInputAction.send
                                  : TextInputAction.search,
                              onSubmitted: (value) {
                                final text = value.trim();
                                if (state.isActive && text.isNotEmpty) {
                                  notifier.submitBarcode(text);
                                  _search.clear();
                                }
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: state.isActive
                                    ? 'Search or enter barcode'
                                    : 'Search roll no or name',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: Insets.md,
                                  vertical: Insets.sm,
                                ),
                                suffixIcon:
                                    state.isActive &&
                                        _search.text.trim().isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.send_rounded),
                                        tooltip: 'Submit barcode',
                                        onPressed: () {
                                          final text = _search.text.trim();
                                          if (text.isNotEmpty) {
                                            notifier.submitBarcode(text);
                                            _search.clear();
                                          }
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            SizedBox(
                              width: double.infinity,
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
                            const SizedBox(height: Insets.sm),
                            // One Wrap rather than a Row. The actions are what this
                            // row is for, so when the count chip will not fit beside
                            // them it drops to its own line instead of squeezing
                            // them; a Row can only do one or the other.
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 8,
                              children: [
                                _SessionActions(
                                  state: state,
                                  notifier: notifier,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.sm,
                                    vertical: Insets.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: Radii.allXs,
                                  ),
                                  // Scales the numbers down rather than truncating
                                  // them when the row is tight.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${state.presentCount}/${state.totalCount} • ${state.attendancePercent.toStringAsFixed(0)}%',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AttendanceRosterTable(
                  state: state,
                  filtered: roster,
                  filter: _filter,
                  onStudentTap: state.isActive
                      ? (entry) {
                          if (!entry.isPresent) {
                            notifier.submitBarcode(entry.student.rollNo);
                          }
                        }
                      : null,
                  onTogglePresent: state.isActive
                      ? (entry) {
                          if (entry.isPresent) {
                            notifier.undoPresent(entry);
                          } else {
                            notifier.submitBarcode(entry.student.rollNo);
                          }
                        }
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CameraSection extends StatelessWidget {
  const _CameraSection({
    required this.controller,
    required this.maxHeight,
    required this.isPaused,
    required this.isScanning,
    required this.onDetect,
    required this.onToggleTorch,
    required this.onFlipCamera,
    required this.onTogglePause,
  });

  final MobileScannerController controller;
  final double maxHeight;
  final bool isPaused;
  final bool isScanning;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onToggleTorch;
  final VoidCallback onFlipCamera;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // The preview never claims more than the caller measured out for it, so a
    // short screen shrinks the camera instead of pushing the roster off.
    final maxCameraHeight = isKeyboardOpen
        ? math.min(120.0, maxHeight)
        : maxHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 120.0, maxHeight: maxCameraHeight),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error, _) => _CameraError(error: error),
            ),
            if (isScanning)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: CustomPaint(
                      size: const Size(200, 130),
                      painter: _ReticlePainter(
                        color: Colors.white,
                        cornerLength: 24,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              ),
            if (!isScanning)
              _ScannerOverlay(isPaused: isPaused, onResume: onTogglePause),
            // Shown only while the camera is actually running, so the control
            // that pauses scanning is never the one sitting on a dead preview.
            if (isScanning)
              Positioned(
                left: 12,
                bottom: 12,
                child: Semantics(
                  button: true,
                  label: 'Pause scanning',
                  child: FilledButton.tonalIcon(
                    onPressed: onTogglePause,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
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
                                onPressed: isScanning ? onToggleTorch : null,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: Insets.xs),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.cameraswitch_outlined),
                        tooltip: 'Switch camera',
                        onPressed: isScanning ? onFlipCamera : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Covers the preview whenever the camera is not running.
///
/// Doubles as the resume control when a session is paused, because a stopped
/// camera gives the operator nothing else to react to. Announced as a live
/// region for the same reason: the state change is otherwise silent.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.isPaused, required this.onResume});

  final bool isPaused;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final headline = isPaused ? 'Scanning paused' : 'Scanner stopped';
    final detail = isPaused
        ? 'Tap to resume'
        : 'Start or resume a session to scan';
    final icon = isPaused ? Icons.play_circle_outline : Icons.videocam_off;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Semantics(
          liveRegion: true,
          label: '$headline. $detail',
          child: InkWell(
            onTap: isPaused ? onResume : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: Insets.xs,
              ),
              // The preview is short and can be short enough for the copy not
              // to fit, so scale the block down instead of clipping it.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(icon, color: Colors.white70, size: 28),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  final Color color;
  final double cornerLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);

    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(r.topRight, r.topRight + Offset(-cornerLength, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(
      r.bottomLeft,
      r.bottomLeft + Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      r.bottomLeft,
      r.bottomLeft + Offset(0, -cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + Offset(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.color != color ||
      old.cornerLength != cornerLength ||
      old.strokeWidth != strokeWidth;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: Insets.allMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white70,
              size: 36,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              isPermission
                  ? 'Camera permission required'
                  : 'Camera unavailable',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.xxs),
            Text(
              isPermission
                  ? 'Please enable camera access in device settings to scan barcodes.'
                  : (error.errorDetails?.message ?? error.errorCode.name),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
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
        padding: EdgeInsets.symmetric(vertical: Insets.xs),
        child: SizedBox(
          height: Insets.lg,
          width: Insets.lg,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // A start, resume or finish is in flight. Showing the spinner replaces the
    // button so a second tap has nothing to hit.
    if (state.isSessionBusy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Insets.xs),
        child: SizedBox(
          height: Insets.lg,
          width: Insets.lg,
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
        // A Wrap, not a Row: on a narrow screen the two controls stack instead
        // of overflowing. Each button is hugged back to its own width first,
        // because a button otherwise takes the full width of a wrap run and
        // leaves no room for its neighbour.
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: () => notifier.startSession(),
              child: Text('Start ${state.tripType.label} Session'),
            ),
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
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.xs,
                  vertical: Insets.xs,
                ),
                alignment: Alignment.center,
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
      if (state.presentCount == 0) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => notifier.discardSession(),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => notifier.finishSession(),
              child: Text('Finish (${state.tripType.label})'),
            ),
          ],
        );
      }
      return FilledButton(
        onPressed: () => notifier.finishSession(),
        child: Text('Finish (${state.tripType.label})'),
      );
    }
    if (state.phase == AttendancePhase.paused) {
      // Resume lives on the camera preview, so the only session action offered
      // here is the one that cannot be reached from anywhere else.
      return FilledButton(
        onPressed: () => notifier.finishSession(),
        child: Text('Finish (${state.tripType.label})'),
      );
    }
    if (state.phase == AttendancePhase.finished) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            onPressed: () => notifier.startSession(),
            child: Text('Start ${state.tripType.label} Session'),
          ),
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
