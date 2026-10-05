import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/theme/app_theme.dart';
import 'package:onboard/core/theme/theme_mode_controller.dart';
import 'package:onboard/main.dart';

class _FakeStore implements ThemePreferenceStore {
  _FakeStore(this._mode);

  final ThemeMode _mode;

  @override
  ThemeMode read() => _mode;

  @override
  Future<void> write(ThemeMode mode) async {}
}

Future<void> _pump(WidgetTester tester, ThemeMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [themeStoreProvider.overrideWithValue(_FakeStore(mode))],
      child: const OnBoardApp(),
    ),
  );

  // The dashboard runs a repeating animation, so pumpAndSettle never returns.
  // A fixed pump is enough for the theme and the AnnotatedRegion to apply.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The overlay style the app publishes for the system bars.
SystemUiOverlayStyle _systemBars(WidgetTester tester) {
  return tester
      .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .firstWhere(
        (r) =>
            r.value.statusBarIconBrightness != null &&
            r.value.statusBarColor == Colors.transparent,
      )
      .value;
}

void main() {
  testWidgets('light mode requests dark status bar icons', (tester) async {
    await _pump(tester, ThemeMode.light);
    expect(_systemBars(tester).statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('dark mode requests light status bar icons', (tester) async {
    await _pump(tester, ThemeMode.dark);
    expect(_systemBars(tester).statusBarIconBrightness, Brightness.light);
  });

  testWidgets('system bars stay transparent so content draws behind them', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await _pump(tester, mode);
      final bars = _systemBars(tester);
      expect(bars.statusBarColor, Colors.transparent);
      expect(bars.systemNavigationBarColor, Colors.transparent);
      expect(
        bars.systemNavigationBarIconBrightness,
        bars.statusBarIconBrightness,
      );
    }
  });

  testWidgets('the app honours an explicit theme mode', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await _pump(tester, mode);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        mode,
      );
    }
  });

  test('both themes give the status bar an opaque app bar to sit on', () {
    // The bars are transparent, so the icons are actually read against the
    // app bar colour underneath them.
    expect(AppTheme.light.appBarTheme.backgroundColor, isNotNull);
    expect(AppTheme.dark.appBarTheme.backgroundColor, isNotNull);
  });
}
