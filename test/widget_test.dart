import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/router/app_router.dart';
import 'package:onboard/core/theme/theme_mode_controller.dart';
import 'package:onboard/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app against a throwaway database file.
///
/// This is a smoke test, not a feature test: its job is to prove the widget
/// tree builds, the router configuration is valid — including the nested
/// `/students/import` and `/attendance/debug` routes — and the screens query
/// their data without throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboard_smoke');
    // The database lives in the application documents directory, which is not
    // available under the test binding, so point it at a temporary one.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// The app with a real, empty theme store (normally installed in `main`).
  Widget app() {
    return ProviderScope(
      overrides: [
        themeStoreProvider.overrideWithValue(SharedPrefsThemeStore(prefs)),
      ],
      child: const OnBoardApp(),
    );
  }

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('app boots and the Students screen offers the Excel import', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Students'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Students'), findsWidgets);
    expect(find.byTooltip('Import from Excel'), findsOneWidget);
  });

  testWidgets('the attendance route builds', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    ).read(routerProvider);

    router.go('/attendance');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Take Attendance'), findsWidgets);

    // Unmount so the autoDispose providers drain inside the test rather than
    // stranding Riverpod's disposal timer past the end of it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the attendance history routes build', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    ).read(routerProvider);

    router.go('/history');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Attendance History'), findsWidgets);

    router.go('/history/1');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Session Details'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the settings and restore routes build', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    ).read(routerProvider);

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Back up data'), findsOneWidget);
    expect(find.text('Restore data'), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Clear all data'), findsOneWidget);

    router.go('/settings/restore');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No backup selected.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the appearance setting switches between light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    ).read(routerProvider);

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    MaterialApp materialApp() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp().themeMode, ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(materialApp().themeMode, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(materialApp().themeMode, ThemeMode.light);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
