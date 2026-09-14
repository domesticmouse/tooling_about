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

  group('FeedbackRatingCard GenUI Component', () {
    testWidgets(
      'renders prompt, stars, comment box, and disabled submit button',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        final transport = service.transport;

        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "fb_surf_1",
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
    "surfaceId": "fb_surf_1",
    "components": [
      {
        "id": "root",
        "component": "FeedbackRatingCard",
        "prompt": "How satisfied are you with this answer?"
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
                id: 'msg-fb-1',
                role: MessageRole.assistant,
                content: 'Feedback request:',
                surfaceIds: ['fb_surf_1'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('How satisfied are you with this answer?'),
          findsOneWidget,
        );
        // By default, 5 star icons are rendered in the row
        expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
        // Comment text field exists
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText?.contains('Additional feedback') == true,
          ),
          findsOneWidget,
        );

        // Submit button exists and is disabled initially (rating is 0)
        final submitFinder = find.widgetWithText(
          FilledButton,
          'Submit Feedback',
        );
        expect(submitFinder, findsOneWidget);
        final FilledButton button = tester.widget(submitFinder);
        expect(button.onPressed, isNull);

        service.dispose();
      },
    );

    testWidgets('rating selection, comment entry, and submission', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "fb_surf_submit",
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
    "surfaceId": "fb_surf_submit",
    "components": [
      {
        "id": "root",
        "component": "FeedbackRatingCard",
        "prompt": "Rate the code review quality",
        "submitLabel": "Send Review"
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
              id: 'msg-fb-submit',
              role: MessageRole.assistant,
              content: 'Review feedback:',
              surfaceIds: ['fb_surf_submit'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 4th star (stars are rendered via IconButton with tooltips)
      final star4Finder = find.byTooltip('4 of 5 stars');
      expect(star4Finder, findsOneWidget);
      await tester.tap(star4Finder);
      await tester.pumpAndSettle();

      // Button should now be enabled with custom label 'Send Review'
      final submitFinder = find.widgetWithText(FilledButton, 'Send Review');
      expect(submitFinder, findsOneWidget);
      final FilledButton enabledButton = tester.widget(submitFinder);
      expect(enabledButton.onPressed, isNotNull);

      // Enter comment
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Additional feedback') == true,
        ),
        'Very thorough analysis!',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify completion message in the card
      expect(
        find.text('Thank you for your feedback! (4/5 stars)'),
        findsOneWidget,
      );

      // Verify chat message added
      expect(
        find.text(
          'Feedback for "Rate the code review quality": 4/5 stars - "Very thorough analysis!"',
        ),
        findsOneWidget,
      );

      // Verify logged in processLogs
      expect(
        service.processLogs.any(
          (l) => l.message.contains(
            'Feedback for "Rate the code review quality": 4/5 stars - "Very thorough analysis!"',
          ),
        ),
        isTrue,
      );

      service.dispose();
    });

    testWidgets('respects allowFeedbackText: false and custom maxRating', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "fb_surf_no_comment",
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
    "surfaceId": "fb_surf_no_comment",
    "components": [
      {
        "id": "root",
        "component": "FeedbackRatingCard",
        "prompt": "Rate overall experience",
        "maxRating": 3,
        "allowFeedbackText": false
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
              id: 'msg-fb-no-comment',
              role: MessageRole.assistant,
              content: 'Quick rating:',
              surfaceIds: ['fb_surf_no_comment'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no feedback comment TextField is rendered when allowFeedbackText is false
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Additional feedback') == true,
        ),
        findsNothing,
      );

      // Check maxRating 3
      expect(find.byTooltip('1 of 3 stars'), findsOneWidget);
      expect(find.byTooltip('2 of 3 stars'), findsOneWidget);
      expect(find.byTooltip('3 of 3 stars'), findsOneWidget);
      expect(find.byTooltip('4 of 3 stars'), findsNothing);

      // Select 3 stars
      await tester.tap(find.byTooltip('3 of 3 stars'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Feedback'));
      await tester.pumpAndSettle();

      // Verify formatted response without comment
      expect(
        find.text('Feedback for "Rate overall experience": 3/3 stars'),
        findsOneWidget,
      );

      service.dispose();
    });
  });
}
