import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/router/app_router.dart';
import 'package:onboard/main.dart';

/// Boots the real app against a throwaway database file.
///
/// This is a smoke test, not a feature test: its job is to prove the widget
/// tree builds, the router configuration is valid — including the nested
/// `/students/import` and `/attendance/debug` routes — and the screens query
/// their data without throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboard_smoke');
    // The database lives in the application documents directory, which is not
    // available under the test binding, so point it at a temporary one.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

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
    await tester.pumpWidget(const ProviderScope(child: OnBoardApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Students'), findsWidgets);
    expect(find.byTooltip('Import from Excel'), findsOneWidget);
  });

  testWidgets('the manual barcode debug route builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OnBoardApp()));
    await tester.pumpAndSettle();

    // Reuses the running app's container rather than building a second one, so
    // there is no extra autoDispose cycle to drain at teardown. Going straight
    // to the nested route also keeps this off the scanner plugin's method
    // channels, leaving a pure "is the route wired up" check.
    final router = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    ).read(routerProvider);

    router.go('/attendance/debug');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Barcode Debug'), findsWidgets);
    expect(find.text('Match'), findsOneWidget);

    // Unmount so the autoDispose providers drain inside the test rather than
    // stranding Riverpod's disposal timer past the end of it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the attendance history routes build', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OnBoardApp()));
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
}
