import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../barcode_controller.dart';
import '../widgets/barcode_result_card.dart';

/// Live camera scanner for student ID cards.
///
/// Scans are resolved against the roster and reported on screen. Nothing is
/// written to `attendance_records` yet — this round establishes the match, and
/// marking attendance is deliberately left for later.
class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    // Stops the same card being reported on every single frame while the
    // operator lines it up.
    detectionTimeoutMs: 250,
  );

  @override
  void initState() {
    super.initState();
    // Deferred: loadStudents publishes its loading state immediately, and
    // mutating a provider while the tree is building is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(barcodeControllerProvider.notifier).loadStudents();
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // A frame can carry several barcodes; the first with a value is taken and
    // the rest ignored, because one card is in front of the lens at a time.
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        ref.read(barcodeControllerProvider.notifier).onBarcodeScanned(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(barcodeControllerProvider);
    final controller = ref.read(barcodeControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan ID Card'),
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
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, _) => _CameraError(error: error),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final window = _scanWindow(constraints.biggest);
                    return Stack(
                      children: [
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CutoutPainter(
                              window: window,
                              borderColor: theme.colorScheme.primary,
                            ),
                            size: constraints.biggest,
                          ),
                        ),
                        _ScannerToolbar(controller: _scanner),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _buildResultPanel(context, state, controller),
        ],
      ),
    );
  }

  Widget _buildResultPanel(
    BuildContext context,
    BarcodeState state,
    BarcodeController controller,
  ) {
    final theme = Theme.of(context);

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null) {
      return _Panel(
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.error!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: controller.loadStudents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.students.isEmpty) {
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No students registered yet. Import a roster before scanning.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/students/import'),
              child: const Text('Import'),
            ),
          ],
        ),
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.lastResult == null)
            Text(
              '${state.students.length} students loaded. Point the camera at an ID card.',
              style: theme.textTheme.bodyMedium,
            )
          else
            BarcodeResultCard(
              result: state.lastResult!,
              onDismiss: controller.clearResult,
            ),
        ],
      ),
    );
  }
}

/// The area the camera is asked to read, centred and sized to suit a card.
Rect _scanWindow(Size size) {
  final width = size.width * 0.8;
  final height = width * 0.6;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: width,
    height: height,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

/// Torch and camera-switch controls, shown only when the device supports them.
class _ScannerToolbar extends StatelessWidget {
  const _ScannerToolbar({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: ValueListenableBuilder<TorchState>(
        valueListenable: controller.torchState,
        builder: (context, torchState, _) {
          return Column(
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
                        onPressed: controller.toggleTorch,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.cameraswitch_outlined),
                tooltip: 'Switch camera',
                onPressed: controller.switchCamera,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dims the frame around the scan window so the operator knows where to aim.
class _CutoutPainter extends CustomPainter {
  _CutoutPainter({required this.window, required this.borderColor});

  final Rect window;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(window, const Radius.circular(16));
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(cutout),
    );

    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      cutout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(_CutoutPainter oldDelegate) =>
      oldDelegate.window != window || oldDelegate.borderColor != borderColor;
}

/// Shown when the camera cannot start, most often because permission was denied.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Camera access is required to scan ID cards.\n'
                        'Enable it in Settings › OnBoard › Camera.'
                    : 'The camera could not be started.\n${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}