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

  group('ConfirmationCard GenUI Component', () {
    testWidgets('renders title, description, details, and default buttons', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "conf_surf_1",
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
    "surfaceId": "conf_surf_1",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Deploy to Staging",
        "description": "Trigger automated staging deployment.",
        "details": "git push staging main"
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
              id: 'msg-conf-1',
              role: MessageRole.assistant,
              content: 'Please confirm:',
              surfaceIds: ['conf_surf_1'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deploy to Staging'), findsOneWidget);
      expect(
        find.text('Trigger automated staging deployment.'),
        findsOneWidget,
      );
      expect(find.text('git push staging main'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      service.dispose();
    });

    testWidgets('renders destructive styling and custom button labels', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);
      final transport = service.transport;

      transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "conf_surf_dest",
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
    "surfaceId": "conf_surf_dest",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Drop Database Table",
        "description": "This will permanently drop the users table.",
        "confirmLabel": "Yes, Delete",
        "cancelLabel": "No, Keep",
        "isDestructive": true
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
              id: 'msg-dest',
              role: MessageRole.assistant,
              content: 'Dangerous action requested:',
              surfaceIds: ['conf_surf_dest'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drop Database Table'), findsOneWidget);
      expect(
        find.text('This will permanently drop the users table.'),
        findsOneWidget,
      );
      expect(find.text('Yes, Delete'), findsOneWidget);
      expect(find.text('No, Keep'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      service.dispose();
    });

    testWidgets(
      'approving action updates UI state and dispatches transport message',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        final transport = service.transport;

        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "conf_surf_approve",
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
    "surfaceId": "conf_surf_approve",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Run Flutter Test",
        "description": "Execute flutter test on project.",
        "details": "flutter test --coverage"
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
                id: 'msg-approve',
                role: MessageRole.assistant,
                content: 'Confirmation required:',
                surfaceIds: ['conf_surf_approve'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap Approve
        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();

        // Verify status badge shows "Approved"
        expect(find.text('Approved'), findsWidgets);

        // Verify buttons are no longer present
        expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);

        // Verify formatted response was posted to chat
        expect(
          find.text(
            'Confirmation for "Run Flutter Test": Approved (flutter test --coverage)',
          ),
          findsOneWidget,
        );

        // Verify logged in processLogs
        expect(
          service.processLogs.any(
            (l) => l.message.contains(
              'Confirmation for "Run Flutter Test": Approved (flutter test --coverage)',
            ),
          ),
          isTrue,
        );

        service.dispose();
      },
    );

    testWidgets(
      'rejecting action updates UI state and dispatches transport message',
      (tester) async {
        final service = AntigravityService(prefs: prefs);
        final transport = service.transport;

        transport.addChunk('''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "conf_surf_reject",
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
    "surfaceId": "conf_surf_reject",
    "components": [
      {
        "id": "root",
        "component": "ConfirmationCard",
        "title": "Restart Server",
        "description": "Reboot the production cluster node."
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
                id: 'msg-reject',
                role: MessageRole.assistant,
                content: 'Confirmation required:',
                surfaceIds: ['conf_surf_reject'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap Reject
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();

        // Verify status badge shows "Rejected"
        expect(find.text('Rejected'), findsWidgets);

        // Verify formatted response was posted to chat
        expect(
          find.text('Confirmation for "Restart Server": Rejected'),
          findsOneWidget,
        );

        service.dispose();
      },
    );
  });
}
