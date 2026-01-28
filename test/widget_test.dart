import 'package:flutter_test/flutter_test.dart';

import 'package:desert_eye/main.dart';

void main() {
  testWidgets('DesertEye app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const DesertEyeApp());

    expect(find.text('DesertEye'), findsOneWidget);
  });
}
