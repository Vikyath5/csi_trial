import 'package:flutter_test/flutter_test.dart';
import 'package:neurovision_platform/platform_core/app.dart';

void main() {
  testWidgets('NeuroVision app renders dashboard', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NeuroVisionApp());

    // Verify the app title is displayed
    expect(find.text('NeuroVision'), findsOneWidget);

    // Verify the two mode buttons are present
    expect(find.text('Learning Mode'), findsOneWidget);
    expect(find.text('Vision Mode'), findsOneWidget);
  });
}
