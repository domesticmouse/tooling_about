import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' hide ChatMessage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/models/chat_message.dart';
import 'package:tooling_about/services/antigravity_service.dart';
import 'package:tooling_about/ui/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildChatApp({
    required AntigravityService service,
    List<ChatMessage>? initialMessages,
  }) {
    return MaterialApp(
      home: ChatScreen(service: service, initialMessages: initialMessages),
    );
  }

  group('ChatScreen UI Interactions', () {
    testWidgets('preset prompt chip triggers message sending', (tester) async {
      final service = AntigravityService(prefs: prefs);

      await tester.pumpWidget(buildChatApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Write a Flutter widget'), findsOneWidget);

      // Tap preset prompt chip
      await tester.tap(find.text('Write a Flutter widget'));
      await tester.pump();

      // Should display user message in the chat list
      expect(
        find.text('Write an animated Flutter button widget'),
        findsOneWidget,
      );
    });

    testWidgets('app bar settings icon opens settings dialog', (tester) async {
      final service = AntigravityService(prefs: prefs);

      await tester.pumpWidget(buildChatApp(service: service));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Antigravity Settings'), findsOneWidget);
    });

    testWidgets(
      'clear conversation button empties chat messages and shows SnackBar',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        await tester.pumpWidget(
          buildChatApp(
            service: service,
            initialMessages: [
              ChatMessage(
                id: 'msg-1',
                role: MessageRole.user,
                content: 'Test message for clear',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test message for clear'), findsOneWidget);

        final clearButtonFinder = find.byIcon(Icons.delete_outline);
        expect(clearButtonFinder, findsOneWidget);

        // Tap clear conversation button
        await tester.tap(clearButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Test message for clear'), findsNothing);
        expect(find.text('Welcome to Antigravity'), findsOneWidget);
      },
    );

    testWidgets('thinking process toggle expands and collapses thoughts', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);

      await tester.pumpWidget(
        buildChatApp(
          service: service,
          initialMessages: [
            ChatMessage(
              id: 'bot-1',
              role: MessageRole.assistant,
              content: 'Here is your answer.',
              thoughts:
                  'Step 1: Ponder deeply. Step 2: Formulate concise response.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking Process'), findsOneWidget);
      // Thoughts should initially be visible
      expect(
        find.text('Step 1: Ponder deeply. Step 2: Formulate concise response.'),
        findsOneWidget,
      );

      // Tap thinking process header to collapse
      await tester.tap(find.text('Thinking Process'));
      await tester.pumpAndSettle();

      expect(
        find.text('Step 1: Ponder deeply. Step 2: Formulate concise response.'),
        findsNothing,
      );

      // Tap again to expand
      await tester.tap(find.text('Thinking Process'));
      await tester.pumpAndSettle();

      expect(
        find.text('Step 1: Ponder deeply. Step 2: Formulate concise response.'),
        findsOneWidget,
      );
    });

    testWidgets('displays streaming indicators and message errors', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);

      await tester.pumpWidget(
        buildChatApp(
          service: service,
          initialMessages: [
            ChatMessage(
              id: 'stream-think',
              role: MessageRole.assistant,
              content: '',
              isStreaming: true,
              isThinking: true,
            ),
            ChatMessage(
              id: 'stream-gen',
              role: MessageRole.assistant,
              content: '',
              isStreaming: true,
              isThinking: false,
            ),
            ChatMessage(
              id: 'err-msg',
              role: MessageRole.assistant,
              content: 'Partial message',
              error: 'Connection interrupted by host',
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Thinking...'), findsOneWidget);
      expect(find.text('Generating...'), findsOneWidget);
      expect(find.text('Connection interrupted by host'), findsOneWidget);
    });

    testWidgets(
      'renders GenUI Surface inside assistant message bubble when surfaceIds present',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        // Feed A2UI streaming chunks through GenUI transport adapter
        final transport =
            service.conversation.transport as A2uiTransportAdapter;
        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "test_surf",
    "catalogId": "$basicCatalogId",
    "sendDataModel": true
  }
}
```
''');
        transport.addChunk('''
```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "test_surf",
    "components": [
      {
        "id": "root",
        "component": "Text",
        "text": "Hello from GenUI surface!"
      }
    ]
  }
}
```
''');
        // Allow microtasks for stream parsing
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          buildChatApp(
            service: service,
            initialMessages: [
              ChatMessage(
                id: 'genui-bot-1',
                role: MessageRole.assistant,
                content: 'Here is your interactive UI:',
                surfaceIds: ['test_surf'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Surface), findsOneWidget);
        expect(find.text('Here is your interactive UI:'), findsOneWidget);
        expect(find.text('Hello from GenUI surface!'), findsOneWidget);

        service.dispose();
      },
    );

    testWidgets(
      'Shift+Enter inserts newline and plain Enter sends multiline message',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        await tester.pumpWidget(buildChatApp(service: service));
        await tester.pumpAndSettle();

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // Tap to focus and enter initial text
        await tester.tap(textFieldFinder);
        await tester.enterText(textFieldFinder, 'Line 1');
        await tester.pump();

        // Send Shift+Enter
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        // Verify text field now has a newline inserted
        final textFieldWidget = tester.widget<TextField>(textFieldFinder);
        expect(textFieldWidget.controller?.text, 'Line 1\n');

        // Append line 2
        await tester.enterText(textFieldFinder, 'Line 1\nLine 2');
        await tester.pump();

        // Plain Enter should send the message
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        // The user message should be added to the chat
        expect(find.text('Line 1\nLine 2'), findsOneWidget);
        // And the text controller should be cleared
        expect(textFieldWidget.controller?.text, '');
      },
    );

    testWidgets(
      'Shift+NumpadEnter inserts newline and plain NumpadEnter sends message',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        await tester.pumpWidget(buildChatApp(service: service));
        await tester.pumpAndSettle();

        final textFieldFinder = find.byType(TextField);
        await tester.tap(textFieldFinder);
        await tester.enterText(textFieldFinder, 'Part A');
        await tester.pump();

        // Send Shift+NumpadEnter
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        final textFieldWidget = tester.widget<TextField>(textFieldFinder);
        expect(textFieldWidget.controller?.text, 'Part A\n');

        // Plain NumpadEnter sends the message
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        await tester.pump();

        expect(find.text('Part A'), findsOneWidget);
        expect(textFieldWidget.controller?.text, '');
      },
    );

    testWidgets(
      'error banner displays with Settings CTA and Dismiss button when lastError is set',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        service.setLastErrorForTesting(
          'Failed to connect to agent: invalid key',
        );

        await tester.pumpWidget(buildChatApp(service: service));
        await tester.pumpAndSettle();

        expect(
          find.text('Failed to connect to agent: invalid key'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.byTooltip('Dismiss'), findsOneWidget);
      },
    );

    testWidgets('error banner Settings CTA opens SettingsDialog on tap', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      service.setLastErrorForTesting('Failed to initialize');

      await tester.pumpWidget(buildChatApp(service: service));
      await tester.pumpAndSettle();

      final settingsCtaFinder = find.widgetWithText(FilledButton, 'Settings');
      expect(settingsCtaFinder, findsOneWidget);

      await tester.tap(settingsCtaFinder);
      await tester.pumpAndSettle();

      expect(find.text('Antigravity Settings'), findsOneWidget);
    });

    testWidgets('error banner Dismiss button clears error and hides banner', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      service.setLastErrorForTesting('Network error');

      await tester.pumpWidget(buildChatApp(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Network error'), findsOneWidget);

      final dismissFinder = find.byTooltip('Dismiss');
      expect(dismissFinder, findsOneWidget);

      await tester.tap(dismissFinder);
      await tester.pumpAndSettle();

      expect(find.text('Network error'), findsNothing);
      expect(service.lastError, isNull);
    });
  });
}
