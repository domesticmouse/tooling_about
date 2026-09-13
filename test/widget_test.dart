import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tooling_about/main.dart';

void main() {
  testWidgets('Antigravity chat smoke test', (WidgetTester tester) async {
    // Build our chat app and trigger a frame.
    await tester.pumpWidget(const AntigravityChatApp());

    // Verify header, welcome screen, and subprocess trace elements are displayed.
    expect(find.text('Antigravity Chat'), findsOneWidget);
    expect(find.text('Welcome to Antigravity'), findsOneWidget);
    expect(find.text('Subprocess Trace'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Enter a message in the chat input text field.
    final chatInputFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText?.contains('Message Antigravity') == true,
    );
    expect(chatInputFinder, findsOneWidget);

    await tester.enterText(chatInputFinder, 'Hello Antigravity');
    expect(find.text('Hello Antigravity'), findsOneWidget);
  });
}
