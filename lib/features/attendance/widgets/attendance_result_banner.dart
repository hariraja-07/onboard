import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../attendance_controller.dart';
import '../models/attendance_models.dart';

import 'dart:async';

/// A compact banner showing the result of the most recent scan.
///
/// Automatically animates in, announces via accessibility live region,
/// and auto-dismisses after a timeout so it never remains stale.
class AttendanceResultBanner extends StatefulWidget {
  const AttendanceResultBanner({super.key, required this.state});

  final AttendanceState state;

  @override
  State<AttendanceResultBanner> createState() => _AttendanceResultBannerState();
}

class _AttendanceResultBannerState extends State<AttendanceResultBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.state.lastOutcome != null) {
      _triggerEntrance();
    }
  }

  @override
  void didUpdateWidget(AttendanceResultBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final outcome = widget.state.lastOutcome;
    final oldOutcome = oldWidget.state.lastOutcome;
    final barcode = widget.state.lastBarcode;
    final oldBarcode = oldWidget.state.lastBarcode;
    final record = widget.state.lastRecord;
    final oldRecord = oldWidget.state.lastRecord;

    if (outcome != null &&
        (outcome != oldOutcome ||
            barcode != oldBarcode ||
            record != oldRecord)) {
      _triggerEntrance();
    } else if (outcome == null && oldOutcome != null) {
      _dismissTimer?.cancel();
      _controller.reverse();
    }
  }

  void _triggerEntrance() {
    _dismissTimer?.cancel();
    _controller.forward(from: 0);

    final outcome = widget.state.lastOutcome;
    final duration = (outcome == AttendanceScanOutcome.marked)
        ? const Duration(seconds: 3)
        : const Duration(seconds: 5);

    _dismissTimer = Timer(duration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.state.lastOutcome;
    if (outcome == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = _backgroundColor(theme, outcome);
    final foreground = _foregroundColor(theme, outcome);
    final icon = _icon(outcome);

    final student = widget.state.lastStudent;
    final line1 = outcome.label;
    final line2 = switch (outcome) {
      AttendanceScanOutcome.marked =>
        student != null
            ? (student.name.isNotEmpty
                  ? '${student.name} (${student.rollNo})'
                  : student.rollNo)
            : null,
      AttendanceScanOutcome.alreadyPresent =>
        student != null
            ? (student.name.isNotEmpty
                  ? '${student.name} (${student.rollNo})'
                  : student.rollNo)
            : null,
      AttendanceScanOutcome.notFound =>
        widget.state.lastBarcode != null && widget.state.lastBarcode!.isNotEmpty
            ? 'Barcode: ${widget.state.lastBarcode}'
            : '',
      AttendanceScanOutcome.ambiguous =>
        widget.state.lastBarcode != null && widget.state.lastBarcode!.isNotEmpty
            ? 'Ambiguous barcode: ${widget.state.lastBarcode}'
            : '',
    };
    final line3 =
        student != null &&
            (outcome == AttendanceScanOutcome.marked ||
                outcome == AttendanceScanOutcome.alreadyPresent)
        ? '${student.boardingPoint}${student.institution.isNotEmpty ? ' • ${student.institution}' : ''}'
        : null;

    final fullAnnouncement = [
      line1,
      if (line2 != null && line2.isNotEmpty) line2,
      if (line3 != null && line3.isNotEmpty) line3,
    ].join('. ');

    return SizeTransition(
      sizeFactor: _fadeAnimation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Semantics(
            liveRegion: true,
            label: fullAnnouncement,
            child: Material(
              color: color,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Icon(icon, color: foreground)),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                          if (line2 != null && line2.isNotEmpty)
                            Text(
                              line2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (line3 != null && line3.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: foreground,
                                  ),
                                  const SizedBox(width: Insets.xxs),
                                  Expanded(
                                    child: Text(
                                      line3,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: foreground),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(ThemeData theme, AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return theme.colorScheme.primaryContainer;
      case AttendanceScanOutcome.alreadyPresent:
        return theme.colorScheme.tertiaryContainer;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return theme.colorScheme.errorContainer;
    }
  }

  Color _foregroundColor(ThemeData theme, AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return theme.colorScheme.onPrimaryContainer;
      case AttendanceScanOutcome.alreadyPresent:
        return theme.colorScheme.onTertiaryContainer;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return theme.colorScheme.onErrorContainer;
    }
  }

  IconData _icon(AttendanceScanOutcome outcome) {
    switch (outcome) {
      case AttendanceScanOutcome.marked:
        return Icons.check_circle;
      case AttendanceScanOutcome.alreadyPresent:
        return Icons.info;
      case AttendanceScanOutcome.notFound:
      case AttendanceScanOutcome.ambiguous:
        return Icons.warning;
    }
  }
}
