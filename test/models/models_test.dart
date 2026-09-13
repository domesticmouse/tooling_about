import 'package:flutter_test/flutter_test.dart';
import 'package:tooling_about/models/chat_message.dart';
import 'package:tooling_about/models/process_log_entry.dart';

void main() {
  group('ChatMessage', () {
    test('instantiates with default values and auto-generated timestamp', () {
      final before = DateTime.now().subtract(const Duration(milliseconds: 10));
      final msg = ChatMessage(id: 'msg-1', role: MessageRole.user);
      final after = DateTime.now().add(const Duration(milliseconds: 10));

      expect(msg.id, 'msg-1');
      expect(msg.role, MessageRole.user);
      expect(msg.content, '');
      expect(msg.thoughts, isNull);
      expect(msg.isStreaming, isFalse);
      expect(msg.isThinking, isFalse);
      expect(msg.error, isNull);
      expect(msg.timestamp.isAfter(before), isTrue);
      expect(msg.timestamp.isBefore(after), isTrue);
    });

    test('accepts custom timestamp and explicit parameters', () {
      final customTime = DateTime(2026, 1, 1, 12, 0, 0);
      final msg = ChatMessage(
        id: 'msg-2',
        role: MessageRole.assistant,
        content: 'Hello!',
        thoughts: 'Internal thought trace',
        isStreaming: true,
        isThinking: true,
        error: 'Timeout error',
        timestamp: customTime,
      );

      expect(msg.id, 'msg-2');
      expect(msg.role, MessageRole.assistant);
      expect(msg.content, 'Hello!');
      expect(msg.thoughts, 'Internal thought trace');
      expect(msg.isStreaming, isTrue);
      expect(msg.isThinking, isTrue);
      expect(msg.error, 'Timeout error');
      expect(msg.timestamp, customTime);
    });

    test('role getters return correct boolean for each role', () {
      final userMsg = ChatMessage(id: '1', role: MessageRole.user);
      expect(userMsg.isUser, isTrue);
      expect(userMsg.isAssistant, isFalse);
      expect(userMsg.isSystem, isFalse);

      final assistantMsg = ChatMessage(id: '2', role: MessageRole.assistant);
      expect(assistantMsg.isUser, isFalse);
      expect(assistantMsg.isAssistant, isTrue);
      expect(assistantMsg.isSystem, isFalse);

      final systemMsg = ChatMessage(id: '3', role: MessageRole.system);
      expect(systemMsg.isUser, isFalse);
      expect(systemMsg.isAssistant, isFalse);
      expect(systemMsg.isSystem, isTrue);
    });

    test(
      'hasThoughts behaves correctly for null, empty, whitespace, and text',
      () {
        final msg = ChatMessage(id: '1', role: MessageRole.assistant);
        expect(msg.hasThoughts, isFalse);

        msg.thoughts = '';
        expect(msg.hasThoughts, isFalse);

        msg.thoughts = '   \n\t  ';
        expect(msg.hasThoughts, isFalse);

        msg.thoughts = 'Evaluating search options';
        expect(msg.hasThoughts, isTrue);
      },
    );

    test('surfaceIds and hasSurfaces behave correctly', () {
      final msg = ChatMessage(id: '1', role: MessageRole.assistant);
      expect(msg.surfaceIds, isEmpty);
      expect(msg.hasSurfaces, isFalse);

      final msgWithSurfaces = ChatMessage(
        id: '2',
        role: MessageRole.assistant,
        surfaceIds: ['surface_a', 'surface_b'],
      );
      expect(msgWithSurfaces.hasSurfaces, isTrue);
      expect(msgWithSurfaces.surfaceIds, ['surface_a', 'surface_b']);
    });

    test('displayContent cleans A2UI protocol json blocks when hasSurfaces is true', () {
      final textWithA2ui = '''
Here is the interactive form:
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "surf_1",
    "catalogId": "basic",
    "sendDataModel": true
  }
}
```
Feel free to submit!
''';
      final msgWithoutSurfaces = ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: textWithA2ui,
      );
      // When hasSurfaces is false, content is returned as-is
      expect(msgWithoutSurfaces.displayContent, textWithA2ui);

      final msgWithSurfaces = ChatMessage(
        id: '2',
        role: MessageRole.assistant,
        content: textWithA2ui,
        surfaceIds: ['surf_1'],
      );
      // When hasSurfaces is true, the A2UI json block is stripped
      expect(
        msgWithSurfaces.displayContent,
        'Here is the interactive form:\n\nFeel free to submit!',
      );
    });
  });

  group('ProcessLogEntry', () {
    test('instantiates with specified properties', () {
      final now = DateTime.now();
      final entry = ProcessLogEntry(
        id: 'log-1',
        timestamp: now,
        message: '>>> call: search',
        direction: LogDirection.outbound,
        level: 'INFO',
        loggerName: 'antigravity.runner',
      );

      expect(entry.id, 'log-1');
      expect(entry.timestamp, now);
      expect(entry.message, '>>> call: search');
      expect(entry.direction, LogDirection.outbound);
      expect(entry.level, 'INFO');
      expect(entry.loggerName, 'antigravity.runner');
    });

    test('direction getters correctly reflect LogDirection enum values', () {
      final inbound = ProcessLogEntry(
        id: '1',
        timestamp: DateTime.now(),
        message: 'in',
        direction: LogDirection.inbound,
      );
      expect(inbound.isInbound, isTrue);
      expect(inbound.isOutbound, isFalse);
      expect(inbound.isSystem, isFalse);
      expect(inbound.isError, isFalse);

      final outbound = ProcessLogEntry(
        id: '2',
        timestamp: DateTime.now(),
        message: 'out',
        direction: LogDirection.outbound,
      );
      expect(outbound.isInbound, isFalse);
      expect(outbound.isOutbound, isTrue);
      expect(outbound.isSystem, isFalse);
      expect(outbound.isError, isFalse);

      final system = ProcessLogEntry(
        id: '3',
        timestamp: DateTime.now(),
        message: 'sys',
        direction: LogDirection.system,
      );
      expect(system.isInbound, isFalse);
      expect(system.isOutbound, isFalse);
      expect(system.isSystem, isTrue);
      expect(system.isError, isFalse);

      final error = ProcessLogEntry(
        id: '4',
        timestamp: DateTime.now(),
        message: 'err',
        direction: LogDirection.error,
      );
      expect(error.isInbound, isFalse);
      expect(error.isOutbound, isFalse);
      expect(error.isSystem, isFalse);
      expect(error.isError, isTrue);
    });

    test(
      'formattedTime pads hours, minutes, seconds, and milliseconds with zeros',
      () {
        final singleDigitTime = DateTime(2026, 9, 14, 8, 5, 3, 42);
        final entry1 = ProcessLogEntry(
          id: '1',
          timestamp: singleDigitTime,
          message: 'msg',
          direction: LogDirection.system,
        );
        expect(entry1.formattedTime, '08:05:03.042');

        final doubleDigitTime = DateTime(2026, 9, 14, 18, 25, 43, 789);
        final entry2 = ProcessLogEntry(
          id: '2',
          timestamp: doubleDigitTime,
          message: 'msg',
          direction: LogDirection.system,
        );
        expect(entry2.formattedTime, '18:25:43.789');

        final zeroTime = DateTime(2026, 9, 14, 0, 0, 0, 0);
        final entry3 = ProcessLogEntry(
          id: '3',
          timestamp: zeroTime,
          message: 'msg',
          direction: LogDirection.system,
        );
        expect(entry3.formattedTime, '00:00:00.000');
      },
    );
  });
}
