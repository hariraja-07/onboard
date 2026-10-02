import 'package:flutter_test/flutter_test.dart';

import 'package:onboard/main.dart';

void main() {
  testWidgets('HomePage shows SCAN button', (WidgetTester tester) async {
    await tester.pumpWidget(const OnboardApp());

    expect(find.text('SCAN'), findsOneWidget);
    expect(find.text('Onboard'), findsOneWidget);
  });
}