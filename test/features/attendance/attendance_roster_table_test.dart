import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/database/database.dart';
import 'package:onboard/core/theme/app_theme.dart';
import 'package:onboard/features/attendance/attendance_controller.dart';
import 'package:onboard/features/attendance/models/attendance_models.dart';
import 'package:onboard/features/attendance/widgets/attendance_roster_table.dart';

Student _student({String name = 'Ada Lovelace', String rollNo = '1'}) =>
    Student(
      id: 1,
      rollNo: rollNo,
      name: name,
      institution: 'Test',
      boardingPoint: 'North Gate',
      createdAt: DateTime(2026),
    );

/// Pumps the roster with a present and an absent row and hands back the
/// rendered tick icon so its colour can be checked against the circle behind it.
Future<Color> _tickColor(
  WidgetTester tester, {
  required Brightness brightness,
}) async {
  final present = StudentAttendance(
    student: _student(),
    status: AttendanceStatus.present,
  );
  final absent = StudentAttendance.absent(_student(name: 'Bob', rollNo: '2'));

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Scaffold(
        body: AttendanceRosterTable(
          state: const AttendanceState(
            phase: AttendancePhase.active,
            sessionId: 1,
          ),
          filtered: [present, absent],
          filter: AttendanceFilter.all,
        ),
      ),
    ),
  );

  final tick = tester.widget<Icon>(find.byIcon(Icons.check));
  return tick.color!;
}

/// Relative luminance per WCAG 2.1, so the assertion is a real ratio.
double _luminance(Color c) {
  double channel(double v) {
    return v <= 0.03928
        ? v / 12.92
        : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('the present tick is legible on its circle in light mode', (
    tester,
  ) async {
    final color = await _tickColor(tester, brightness: Brightness.light);
    expect(color, AppTheme.light.colorScheme.onPrimary);
  });

  testWidgets('the present tick is legible on its circle in dark mode', (
    tester,
  ) async {
    final color = await _tickColor(tester, brightness: Brightness.dark);
    expect(color, AppTheme.dark.colorScheme.onPrimary);
  });

  test('the tick foreground clears 3:1 on the primary fill in both modes', () {
    // The regression: a hardcoded Colors.white on the dark primary sat at
    // 1.57:1, so the tick was invisible rather than merely low contrast.
    for (final scheme in [
      AppTheme.light.colorScheme,
      AppTheme.dark.colorScheme,
    ]) {
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(3.0),
        reason: 'onPrimary on primary in ${scheme.brightness}',
      );
    }
  });
}
