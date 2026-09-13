import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tooling_about/main.dart';

void main() {
  testWidgets('Antigravity chat smoke test', (WidgetTester tester) async {
    // Build our chat app and trigger a frame.
    await tester.pumpWidget(const AntigravityChatApp());

    // Verify header and welcome screen elements are displayed.
    expect(find.text('Antigravity Chat'), findsOneWidget);
    expect(find.text('Welcome to Antigravity'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Enter a message in the text field.
    await tester.enterText(find.byType(TextField), 'Hello Antigravity');
    expect(find.text('Hello Antigravity'), findsOneWidget);
  });
}
