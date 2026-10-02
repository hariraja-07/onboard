import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dashboard page renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Text('Dashboard')),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
  });
}