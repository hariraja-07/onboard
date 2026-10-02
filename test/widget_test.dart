import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/main.dart';

/// Boots the real app against a throwaway database file.
///
/// This is a smoke test, not a feature test: its job is to prove the widget
/// tree builds, the router configuration is valid — including the nested
/// `/students/import` route — and the Students screen queries its data without
/// throwing.
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

  testWidgets('app boots and the Students screen offers the Excel import',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OnBoardApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Students'), findsWidgets);
    expect(find.byTooltip('Import from Excel'), findsOneWidget);
  });
}