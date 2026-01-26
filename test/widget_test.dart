import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy_tales_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap with provider as main() does, but we can verify basic UI presence.
    await tester.pumpWidget(
      const FairyTaleApp(),
    );

    // Verify magic title is present
    expect(find.text('✨ Fairy Tale Maker ✨'), findsOneWidget);
    
    // Verify input fields are present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
  });
}
