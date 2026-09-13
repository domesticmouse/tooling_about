import 'package:flutter/material.dart';
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

  group('MultipleChoiceQuestion GenUI Component', () {
    testWidgets('renders question, options, and always-present Other option', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "mcq_surf",
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
    "surfaceId": "mcq_surf",
    "components": [
      {
        "id": "root",
        "component": "MultipleChoiceQuestion",
        "question": "Which architecture pattern do you prefer?",
        "options": ["Bloc", "Provider", "Riverpod"]
      }
    ]
  }
}
```
''');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        buildChatApp(
          service: service,
          initialMessages: [
            ChatMessage(
              id: 'msg-1',
              role: MessageRole.assistant,
              content: 'Please choose:',
              surfaceIds: ['mcq_surf'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check question
      expect(
        find.text('Which architecture pattern do you prefer?'),
        findsOneWidget,
      );

      // Check standard options
      expect(find.text('Bloc'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Riverpod'), findsOneWidget);

      // Check always-present Other option
      expect(find.text('Other (write your own answer)'), findsOneWidget);

      // Submit button exists and is disabled initially
      final submitButtonFinder = find.widgetWithText(
        ElevatedButton,
        'Submit Answer',
      );
      expect(submitButtonFinder, findsOneWidget);
      final ElevatedButton initialButton = tester.widget(submitButtonFinder);
      expect(initialButton.onPressed, isNull);

      service.dispose();
    });

    testWidgets('single choice selection and submission', (tester) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "mcq_single",
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
    "surfaceId": "mcq_single",
    "components": [
      {
        "id": "root",
        "component": "MultipleChoiceQuestion",
        "question": "What is your favorite fruit?",
        "options": ["Apple", "Banana", "Orange"]
      }
    ]
  }
}
```
''');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        buildChatApp(
          service: service,
          initialMessages: [
            ChatMessage(
              id: 'msg-2',
              role: MessageRole.assistant,
              content: 'Question time:',
              surfaceIds: ['mcq_single'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Banana'
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();

      // Submit button should now be enabled
      final submitButtonFinder = find.widgetWithText(
        ElevatedButton,
        'Submit Answer',
      );
      final ElevatedButton enabledButton = tester.widget(submitButtonFinder);
      expect(enabledButton.onPressed, isNotNull);

      // Tap submit
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Verify message was added to the chat and logged in process logs
      expect(
        find.text('My answer to "What is your favorite fruit?" is: Banana'),
        findsOneWidget,
      );
      expect(
        service.processLogs.any(
          (l) => l.message.contains(
            'My answer to "What is your favorite fruit?" is: Banana',
          ),
        ),
        isTrue,
      );

      // Verify UI shows submitted confirmation
      expect(find.text('Submitted: Banana'), findsOneWidget);

      service.dispose();
    });

    testWidgets(
      'selecting Other allows user to write their own answer and submit',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        final transport = service.transport;

        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "mcq_other",
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
    "surfaceId": "mcq_other",
    "components": [
      {
        "id": "root",
        "component": "MultipleChoiceQuestion",
        "question": "Select target platform",
        "options": ["Android", "iOS"],
        "submitLabel": "Confirm Selection"
      }
    ]
  }
}
```
''');
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          buildChatApp(
            service: service,
            initialMessages: [
              ChatMessage(
                id: 'msg-3',
                role: MessageRole.assistant,
                content: 'Choose platform:',
                surfaceIds: ['mcq_other'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Custom submit label is rendered
        final submitButtonFinder = find.widgetWithText(
          ElevatedButton,
          'Confirm Selection',
        );
        expect(submitButtonFinder, findsOneWidget);

        // Tap 'Other (write your own answer)'
        await tester.tap(find.text('Other (write your own answer)'));
        await tester.pumpAndSettle();

        // TextField should now be visible inside the surface
        final textFieldFinder = find.descendant(
          of: find.byType(Surface),
          matching: find.byType(TextField),
        );
        expect(textFieldFinder, findsOneWidget);

        // Submit button should still be disabled because text field is empty
        ElevatedButton button = tester.widget(submitButtonFinder);
        expect(button.onPressed, isNull);

        // Enter custom text
        await tester.enterText(textFieldFinder, 'macOS Desktop');
        await tester.pumpAndSettle();

        // Submit button should now be enabled
        button = tester.widget(submitButtonFinder);
        expect(button.onPressed, isNotNull);

        // Tap submit
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        // Check submitted text formatted properly in chat message and logs
        expect(
          find.text(
            'My answer to "Select target platform" is: Other: macOS Desktop',
          ),
          findsOneWidget,
        );
        expect(
          service.processLogs.any(
            (l) => l.message.contains(
              'My answer to "Select target platform" is: Other: macOS Desktop',
            ),
          ),
          isTrue,
        );

        // Confirmation shown
        expect(find.text('Submitted: Other: macOS Desktop'), findsOneWidget);

        service.dispose();
      },
    );

    testWidgets(
      'supports multi-selection with allowMultiple: true and combination with Other',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        final transport = service.transport;

        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "mcq_multi",
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
    "surfaceId": "mcq_multi",
    "components": [
      {
        "id": "root",
        "component": "MultipleChoiceQuestion",
        "question": "Which features do you need?",
        "options": ["Dark Mode", "Localization", "Offline Cache"],
        "allowMultiple": true
      }
    ]
  }
}
```
''');
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          buildChatApp(
            service: service,
            initialMessages: [
              ChatMessage(
                id: 'msg-4',
                role: MessageRole.assistant,
                content: 'Select features:',
                surfaceIds: ['mcq_multi'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Check checkboxes exist
        expect(find.byType(Checkbox), findsNWidgets(4)); // 3 options + 1 Other

        // Select Dark Mode and Offline Cache
        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Offline Cache'));
        await tester.pumpAndSettle();

        // Also select Other and type custom feature
        await tester.tap(find.text('Other (write your own answer)'));
        await tester.pumpAndSettle();

        final textFieldFinder = find.descendant(
          of: find.byType(Surface),
          matching: find.byType(TextField),
        );
        await tester.enterText(textFieldFinder, 'Biometrics');
        await tester.pumpAndSettle();

        // Submit
        final submitButtonFinder = find.widgetWithText(
          ElevatedButton,
          'Submit Answer',
        );
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'My answer to "Which features do you need?" is: Dark Mode, Offline Cache, Other: Biometrics',
          ),
          findsOneWidget,
        );
        expect(
          service.processLogs.any(
            (l) => l.message.contains(
              'My answer to "Which features do you need?" is: Dark Mode, Offline Cache, Other: Biometrics',
            ),
          ),
          isTrue,
        );

        expect(
          find.text('Submitted: Dark Mode, Offline Cache, Other: Biometrics'),
          findsOneWidget,
        );

        service.dispose();
      },
    );
  });
}
