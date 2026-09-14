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

  group('GenUI Card Persistence Across App Restarts', () {
    testWidgets(
      'ConfirmationCard survives app restart and restores full interactivity',
      (tester) async {
        final originalService = AntigravityService(prefs: prefs);

        const surfaceId = 'conf_persist_surf';
        const rawContent =
            '''
Please review and confirm the pending deployment:

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "$surfaceId",
    "catalogId": "$basicCatalogId",
    "sendDataModel": true
  }
}
```

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "$surfaceId",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Deploy to Production",
        "description": "Execute database migration and code deployment.",
        "details": "fly deploy --app my-app",
        "confirmLabel": "Deploy Now",
        "cancelLabel": "Cancel",
        "isDestructive": true
      }
    ]
  }
}
```
''';

        // Persist message containing GenUI markup in SharedPreferences
        await originalService.persistMessages([
          ChatMessage(
            id: 'msg-user-1',
            role: MessageRole.user,
            content: 'Deploy to production please',
          ),
          ChatMessage(
            id: 'msg-assistant-1',
            role: MessageRole.assistant,
            content: rawContent,
            surfaceIds: [surfaceId],
          ),
        ]);
        originalService.dispose();

        // Simulate app shutdown and restart: instantiate a new AntigravityService
        final restartedService = AntigravityService(prefs: prefs);

        // Mount ChatScreen without initialMessages (loads from SharedPreferences)
        await tester.pumpWidget(buildChatApp(service: restartedService));
        await tester.pumpAndSettle();

        // Verify message text is clean (displayContent strips raw JSON code block)
        expect(
          find.text('Please review and confirm the pending deployment:'),
          findsOneWidget,
        );

        // Verify the ConfirmationCard components were restored into SurfaceController
        expect(find.text('Deploy to Production'), findsOneWidget);
        expect(
          find.text('Execute database migration and code deployment.'),
          findsOneWidget,
        );
        expect(find.text('fly deploy --app my-app'), findsOneWidget);
        expect(find.text('Deploy Now'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

        // Verify interactivity on restored card: Tap 'Deploy Now'
        await tester.tap(find.text('Deploy Now'));
        await tester.pumpAndSettle();

        // Card should transition to "Approved"
        expect(find.text('Approved'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Deploy Now'), findsNothing);

        // Confirmation chat response was posted
        expect(
          find.text(
            'Confirmation for "Deploy to Production": Approved (fly deploy --app my-app)',
          ),
          findsOneWidget,
        );

        restartedService.dispose();
      },
    );

    testWidgets(
      'FeedbackRatingCard survives app restart and allows user submission',
      (tester) async {
        final originalService = AntigravityService(prefs: prefs);

        const surfaceId = 'fb_persist_surf';
        const rawContent =
            '''
Here is your requested solution.

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "$surfaceId",
    "catalogId": "$basicCatalogId",
    "sendDataModel": true
  }
}
```

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "$surfaceId",
    "components": [
      {
        "id": "root",
        "component": "FeedbackRatingCard",
        "prompt": "Rate the generated code quality",
        "maxRating": 5,
        "allowFeedbackText": true,
        "submitLabel": "Submit Rating"
      }
    ]
  }
}
```
''';

        await originalService.persistMessages([
          ChatMessage(
            id: 'msg-fb-assistant',
            role: MessageRole.assistant,
            content: rawContent,
            surfaceIds: [surfaceId],
          ),
        ]);
        originalService.dispose();

        // Recreate service simulating app reboot
        final restartedService = AntigravityService(prefs: prefs);

        await tester.pumpWidget(buildChatApp(service: restartedService));
        await tester.pumpAndSettle();

        // Verify FeedbackRatingCard restored
        expect(find.text('Rate the generated code quality'), findsOneWidget);
        expect(find.byTooltip('5 of 5 stars'), findsOneWidget);
        final commentFinder = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Additional feedback') == true,
        );
        expect(commentFinder, findsOneWidget);

        // Select 5 stars and submit
        await tester.tap(find.byTooltip('5 of 5 stars'));
        await tester.pumpAndSettle();

        await tester.enterText(commentFinder, 'Clean code!');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Submit Rating'));
        await tester.pumpAndSettle();

        expect(
          find.text('Thank you for your feedback! (5/5 stars)'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Feedback for "Rate the code review quality": 5/5 stars - "Clean code!"',
          ),
          findsNothing, // Prompt title check
        );
        expect(
          find.text(
            'Feedback for "Rate the generated code quality": 5/5 stars - "Clean code!"',
          ),
          findsOneWidget,
        );

        restartedService.dispose();
      },
    );

    testWidgets(
      'MultipleChoiceQuestion survives app restart and renders options',
      (tester) async {
        final originalService = AntigravityService(prefs: prefs);

        const surfaceId = 'mcq_persist_surf';
        const rawContent =
            '''
Please choose your preferred database:

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "$surfaceId",
    "catalogId": "$basicCatalogId",
    "sendDataModel": true
  }
}
```

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "$surfaceId",
    "components": [
      {
        "id": "root",
        "component": "MultipleChoiceQuestion",
        "question": "Which database would you prefer?",
        "options": ["PostgreSQL", "SQLite", "Firestore"]
      }
    ]
  }
}
```
''';

        await originalService.persistMessages([
          ChatMessage(
            id: 'msg-mcq-assistant',
            role: MessageRole.assistant,
            content: rawContent,
            surfaceIds: [surfaceId],
          ),
        ]);
        originalService.dispose();

        // Restart
        final restartedService = AntigravityService(prefs: prefs);

        await tester.pumpWidget(buildChatApp(service: restartedService));
        await tester.pumpAndSettle();

        expect(find.text('Which database would you prefer?'), findsOneWidget);
        expect(find.text('PostgreSQL'), findsOneWidget);
        expect(find.text('SQLite'), findsOneWidget);
        expect(find.text('Firestore'), findsOneWidget);
        expect(find.text('Other (write your own answer)'), findsOneWidget);

        restartedService.dispose();
      },
    );

    testWidgets(
      'initialMessages supplied directly to ChatScreen restores surfaces',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        const surfaceId = 'init_surf';
        const rawContent =
            '''
Initial question:

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "$surfaceId",
    "catalogId": "$basicCatalogId",
    "sendDataModel": true
  }
}
```

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "$surfaceId",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Injected Surface Title",
        "description": "Injected surface description"
      }
    ]
  }
}
```
''';

        final messages = [
          ChatMessage(
            id: 'init-msg-1',
            role: MessageRole.assistant,
            content: rawContent,
            surfaceIds: [surfaceId],
          ),
        ];

        // Pass messages directly via initialMessages
        await tester.pumpWidget(
          buildChatApp(service: service, initialMessages: messages),
        );
        await tester.pumpAndSettle();

        expect(find.text('Injected Surface Title'), findsOneWidget);
        expect(find.text('Injected surface description'), findsOneWidget);

        service.dispose();
      },
    );
  });
}
