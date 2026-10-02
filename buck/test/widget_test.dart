import 'package:flutter_test/flutter_test.dart';
import 'package:buck/main.dart';

void main() {
  testWidgets('Buck app launches to Sign In screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BuckApp());
    expect(find.text('Sign in to Buck'), findsOneWidget);
  });
}
