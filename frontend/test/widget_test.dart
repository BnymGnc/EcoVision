import 'package:flutter_test/flutter_test.dart';

import 'package:ecovision/main.dart';

void main() {
  testWidgets('EcoVision app starts at login', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoVisionApp());
    await tester.pump();

    expect(find.text('Welcome to EcoVision'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
