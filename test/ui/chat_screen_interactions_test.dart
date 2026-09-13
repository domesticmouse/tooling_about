import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
