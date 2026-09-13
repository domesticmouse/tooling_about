import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/models/chat_message.dart';
import 'package:tooling_about/models/process_log_entry.dart';
import 'package:tooling_about/services/antigravity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AntigravityService Unit Tests', () {
    test('initializes with default settings and empty preferences', () {
      final service = AntigravityService(prefs: prefs);

      expect(service.model, 'gemini-3.8-flash');
      expect(service.systemInstructions, contains('Google Antigravity'));
      expect(service.customApiKey, isNull);
      expect(service.isInitializing, isFalse);
      expect(service.isGenerating, isFalse);
      expect(service.isReady, isFalse);
      expect(service.lastError, isNull);
      expect(service.processLogs, isNotEmpty);
      expect(
        service.processLogs.first.message,
        contains('Service initialized'),
      );
    });

    test(
      'captures and categorizes log events via Logger.root hierarchy',
      () async {
        final service = AntigravityService(prefs: prefs);
        service.clearLogs();

        final testLogger = Logger('antigravity.test');

        // Outbound message triggers (5)
        testLogger.info('>>> Sending request payload: {"action": "query"}');
        testLogger.info('Sending user_input to subprocess');
        testLogger.info('Sending tool_response to subprocess');
        testLogger.info('Sending halt_request to subprocess');
        testLogger.info('Sending automated_trigger to subprocess');

        // Inbound message triggers (3)
        testLogger.info('<<< Received tool call: {"tool": "calculator"}');
        testLogger.info('Received WebSocket message from agent');
        testLogger.info('Tool call requested by model');

        // Error triggers (3)
        testLogger.warning('Warning event occurred');
        testLogger.severe('Severe failure in runtime');
        testLogger.info('[Harness Stderr] Subprocess failed on stderr');

        // System triggers (1)
        testLogger.info('Routine background maintenance event');

        // Give microtask loop a beat to process logger stream
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final logs = service.processLogs;
        expect(logs.length, 12);

        // Verify outbound (0..4)
        expect(logs[0].direction, LogDirection.outbound);
        expect(logs[1].direction, LogDirection.outbound);
        expect(logs[2].direction, LogDirection.outbound);
        expect(logs[3].direction, LogDirection.outbound);
        expect(logs[4].direction, LogDirection.outbound);

        // Verify inbound (5..7)
        expect(logs[5].direction, LogDirection.inbound);
        expect(logs[6].direction, LogDirection.inbound);
        expect(logs[7].direction, LogDirection.inbound);

        // Verify errors (8..10)
        expect(logs[8].direction, LogDirection.error);
        expect(logs[9].direction, LogDirection.error);
        expect(logs[10].direction, LogDirection.error);

        // Verify system (11)
        expect(logs[11].direction, LogDirection.system);

        service.dispose();
      },
    );

    test(
      'clearSession cancels generation and logs system clear message',
      () async {
        final service = AntigravityService(prefs: prefs);
        service.clearLogs();

        await service.clearSession();

        expect(service.isGenerating, isFalse);
        expect(
          service.processLogs.any(
            (l) => l.message == 'Clearing conversation session.',
          ),
          isTrue,
        );

        service.dispose();
      },
    );

    test('hasApiKey correctly reflects effective API key presence', () {
      final noKeyService = AntigravityService(prefs: prefs);
      expect(noKeyService.hasApiKey, isFalse);

      final customKeyService = AntigravityService(prefs: prefs);
      customKeyService.updateSettings(apiKey: 'custom-key');
      expect(customKeyService.hasApiKey, isTrue);

      final envKeyService = AntigravityService(
        prefs: prefs,
        environmentApiKey: 'env-key',
      );
      expect(envKeyService.hasApiKey, isTrue);
    });

    test('initializes and provides GenUI controller, conversation, and instructions', () {
      final service = AntigravityService(prefs: prefs);

      expect(service.surfaceController, isNotNull);
      expect(service.conversation, isNotNull);
      expect(service.catalog, isNotNull);
      expect(service.effectiveSystemInstructions, contains('A2UI'));
      expect(service.effectiveSystemInstructions, contains('v0.9'));

      service.dispose();
    });

    test('persistMessages, loadPersistedMessages, and clearPersistedMessages work correctly', () async {
      final service = AntigravityService(prefs: prefs);

      // Initially empty
      expect(service.loadPersistedMessages(), isEmpty);

      final messages = [
        ChatMessage(id: '1', role: MessageRole.user, content: 'User question'),
        ChatMessage(
          id: '2',
          role: MessageRole.assistant,
          content: 'Bot answer',
          thoughts: 'Reasoning...',
        ),
      ];

      await service.persistMessages(messages);

      final loaded = service.loadPersistedMessages();
      expect(loaded.length, 2);
      expect(loaded[0].id, '1');
      expect(loaded[0].role, MessageRole.user);
      expect(loaded[0].content, 'User question');
      expect(loaded[1].id, '2');
      expect(loaded[1].role, MessageRole.assistant);
      expect(loaded[1].content, 'Bot answer');
      expect(loaded[1].thoughts, 'Reasoning...');

      // Clear persisted messages
      await service.clearPersistedMessages();
      expect(service.loadPersistedMessages(), isEmpty);

      service.dispose();
    });

    test('clearSession purges persisted messages from storage', () async {
      final service = AntigravityService(prefs: prefs);
      final messages = [
        ChatMessage(id: '1', role: MessageRole.user, content: 'To be cleared'),
      ];

      await service.persistMessages(messages);
      expect(service.loadPersistedMessages(), isNotEmpty);

      await service.clearSession();
      expect(service.loadPersistedMessages(), isEmpty);

      service.dispose();
    });

    test('exportConversationMarkdown generates structured markdown', () {
      final service = AntigravityService(prefs: prefs);
      final messages = [
        ChatMessage(
          id: '1',
          role: MessageRole.user,
          content: 'What is Antigravity?',
          timestamp: DateTime(2026, 9, 14, 10, 0, 0),
        ),
        ChatMessage(
          id: '2',
          role: MessageRole.assistant,
          content: 'It is an AI agent orchestrator.',
          thoughts: 'Retrieve definition',
          timestamp: DateTime(2026, 9, 14, 10, 0, 5),
        ),
      ];

      final markdown = service.exportConversationMarkdown(messages);
      expect(markdown, contains('# Antigravity Chat Export'));
      expect(markdown, contains('- **Model**: ${service.model}'));
      expect(markdown, contains('- **Total Messages**: 2'));
      expect(markdown, contains('### User (10:00:00)'));
      expect(markdown, contains('What is Antigravity?'));
      expect(markdown, contains('### Assistant (10:00:05)'));
      expect(markdown, contains('> **Thinking Process:**'));
      expect(markdown, contains('It is an AI agent orchestrator.'));

      service.dispose();
    });
  });
}
