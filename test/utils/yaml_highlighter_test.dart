import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tooling_about/utils/yaml_highlighter.dart';

void main() {
  group('FormattedLogMessage', () {
    test('instantiates with specified properties', () {
      const msg = FormattedLogMessage(
        prefix: 'PREFIX',
        content: 'content',
        isStructured: true,
        raw: 'PREFIX: content',
      );
      expect(msg.prefix, 'PREFIX');
      expect(msg.content, 'content');
      expect(msg.isStructured, isTrue);
      expect(msg.raw, 'PREFIX: content');
    });
  });

  group('YamlHighlighter.parse', () {
    test('returns unparsed FormattedLogMessage for non-JSON text', () {
      const raw = 'System startup complete without errors.';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isFalse);
      expect(result.prefix, isNull);
      expect(result.content, raw);
      expect(result.raw, raw);
    });

    test('returns unparsed when braces are present but JSON is invalid', () {
      const raw = '<<< Error: {broken json payload without closing';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isFalse);
      expect(result.prefix, isNull);
      expect(result.content, raw);
      expect(result.raw, raw);
    });

    test('parses simple JSON object alone without prefix', () {
      const raw = '{"model": "gemini-2.5", "temperature": 0.7}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, isNull);
      expect(result.content, contains('model: gemini-2.5'));
      expect(result.content, contains('temperature: 0.7'));
    });

    test('parses JSON array alone', () {
      const raw = '["dart", "flutter", "antigravity"]';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, isNull);
      expect(result.content, contains('- dart'));
      expect(result.content, contains('- flutter'));
      expect(result.content, contains('- antigravity'));
    });

    test('extracts and cleans inbound prefix (<<<)', () {
      const raw = '<<< response: {"status": "ok", "code": 200}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, 'response');
      expect(result.content, contains('status: ok'));
      expect(result.content, contains('code: 200'));
    });

    test('extracts and cleans outbound prefix (>>>)', () {
      const raw = '>>> request: {"prompt": "Hello world"}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, 'request');
      expect(result.content, contains('prompt: Hello world'));
    });

    test('sets prefix to null when prefix becomes empty after strip', () {
      const raw = '<<< : {"data": true}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, isNull);
      expect(result.content, contains('data: true'));
    });

    test('retains custom non-arrow prefix', () {
      const raw = 'custom_tag: {"value": null}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.prefix, 'custom_tag:');
      expect(result.content, contains('value: null'));
    });

    test('formats empty map and empty list correctly', () {
      const raw = '{"emptyMap": {}, "emptyList": []}';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.content, contains('emptyMap: {}'));
      expect(result.content, contains('emptyList: []'));
    });

    test('formats root empty map and root empty list', () {
      final mapResult = YamlHighlighter.parse('{}');
      expect(mapResult.isStructured, isTrue);
      expect(mapResult.content, '{}');

      final listResult = YamlHighlighter.parse('[]');
      expect(listResult.isStructured, isTrue);
      expect(listResult.content, '[]');
    });

    test('formats deeply nested maps and lists', () {
      const raw = '''
      {
        "agent": {
          "capabilities": ["code", "browse", []],
          "settings": {
            "retries": 3,
            "nestedMap": {}
          }
        }
      }
      ''';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.content, contains('agent:'));
      expect(result.content, contains('  capabilities:'));
      expect(result.content, contains('    - code'));
      expect(result.content, contains('    - browse'));
      expect(result.content, contains('    - []'));
      expect(result.content, contains('  settings:'));
      expect(result.content, contains('    retries: 3'));
      expect(result.content, contains('    nestedMap: {}'));
    });

    test('formats lists containing maps', () {
      const raw = '''
      [
        {"name": "first", "val": 1},
        {},
        ["nestedList"]
      ]
      ''';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.content, contains('- name: first'));
      expect(result.content, contains('  val: 1'));
      expect(result.content, contains('- {}'));
      expect(result.content, contains('-'));
      expect(result.content, contains('  - nestedList'));
    });

    test('quotes and escapes strings with special characters', () {
      const raw = '''
      {
        "empty": "",
        "newline": "line1\\nline2",
        "hasColon": "key: value",
        "hasHash": "comment #1",
        "hasBraces": "{braces}",
        "hasBrackets": "[brackets]",
        "startsWithDash": "-leading dash",
        "looksLikeBool": "true",
        "looksLikeNumber": "12345",
        "looksLikeNull": "null",
        "plainString": "normal text"
      }
      ''';
      final result = YamlHighlighter.parse(raw);
      expect(result.isStructured, isTrue);
      expect(result.content, contains('empty: ""'));
      expect(result.content, contains('newline: "line1\\nline2"'));
      expect(result.content, contains('hasColon: "key: value"'));
      expect(result.content, contains('hasHash: "comment #1"'));
      expect(result.content, contains('hasBraces: "{braces}"'));
      expect(result.content, contains('hasBrackets: "[brackets]"'));
      expect(result.content, contains('startsWithDash: "-leading dash"'));
      expect(result.content, contains('looksLikeBool: "true"'));
      expect(result.content, contains('looksLikeNumber: "12345"'));
      expect(result.content, contains('looksLikeNull: "null"'));
      expect(result.content, contains('plainString: normal text'));
    });
  });

  group('YamlHighlighter.buildSyntaxHighlightedSpan', () {
    testWidgets('builds highlighted spans in Light theme', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      const yaml = '''
name: Antigravity
version: 2.5
active: true
tags:
  - "flutter"
  - 42
  - null
description: simple unquoted text
''';

      final span = YamlHighlighter.buildSyntaxHighlightedSpan(
        yaml,
        buildContext,
        fontSize: 12,
      );

      expect(span.style?.fontSize, 12);
      expect(span.children, isNotEmpty);

      // Collect all text from spans
      final fullText = span.toPlainText();
      expect(fullText, yaml);

      // Verify that specific styles exist among the children
      final childSpans = span.children!.whereType<TextSpan>().toList();
      final hasKeySpan = childSpans.any(
        (s) => s.text == 'name:' && s.style?.fontWeight == FontWeight.w600,
      );
      final hasBulletSpan = childSpans.any(
        (s) => s.text == '- ' && s.style?.fontWeight == FontWeight.bold,
      );
      final hasBoolSpan = childActionSpans(childSpans, 'true', FontWeight.bold);
      final hasNumberSpan = childActionSpans(
        childSpans,
        '2.5',
        FontWeight.w500,
      );
      final hasStringSpan = childSpans.any((s) => s.text == '"flutter"');

      expect(hasKeySpan, isTrue);
      expect(hasBulletSpan, isTrue);
      expect(hasBoolSpan, isTrue);
      expect(hasNumberSpan, isTrue);
      expect(hasStringSpan, isTrue);
    });

    testWidgets('builds highlighted spans in Dark theme', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      const yaml = '''
server:
  host: "127.0.0.1"
  port: 8080
  debug: false
''';

      final span = YamlHighlighter.buildSyntaxHighlightedSpan(
        yaml,
        buildContext,
      );

      expect(span.toPlainText(), yaml);
      final childSpans = span.children!.whereType<TextSpan>().toList();
      final hasDarkKeySpan = childSpans.any(
        (s) => s.text == 'server:' && s.style?.color == const Color(0xFF64D2FF),
      );
      final hasDarkStringSpan = childSpans.any(
        (s) =>
            s.text == '"127.0.0.1"' &&
            s.style?.color == const Color(0xFF98E586),
      );
      final hasDarkNumSpan = childSpans.any(
        (s) => s.text == '8080' && s.style?.color == const Color(0xFFFFB86C),
      );
      final hasDarkBoolSpan = childSpans.any(
        (s) => s.text == 'false' && s.style?.color == const Color(0xFFFF79C6),
      );

      expect(hasDarkKeySpan, isTrue);
      expect(hasDarkStringSpan, isTrue);
      expect(hasDarkNumSpan, isTrue);
      expect(hasDarkBoolSpan, isTrue);
    });
  });
}

bool childActionSpans(List<TextSpan> spans, String text, FontWeight weight) {
  return spans.any((s) => s.text == text && s.style?.fontWeight == weight);
}
