import 'dart:convert';

import 'package:flutter/material.dart';

/// Result of parsing a log message, separating any prefix from JSON/YAML payload.
class FormattedLogMessage {
  final String? prefix;
  final String content;
  final bool isStructured;
  final String raw;

  const FormattedLogMessage({
    this.prefix,
    required this.content,
    required this.isStructured,
    required this.raw,
  });
}

/// Utility for converting JSON/structured data into YAML-like text and syntax coloring it.
class YamlHighlighter {
  /// Parses a raw log string, detects embedded JSON, and formats it as YAML if possible.
  static FormattedLogMessage parse(String raw) {
    final trimmed = raw.trim();

    // Look for JSON object or array start
    final objectStart = trimmed.indexOf('{');
    final arrayStart = trimmed.indexOf('[');

    int jsonStart = -1;
    if (objectStart >= 0 && arrayStart >= 0) {
      jsonStart = objectStart < arrayStart ? objectStart : arrayStart;
    } else if (objectStart >= 0) {
      jsonStart = objectStart;
    } else if (arrayStart >= 0) {
      jsonStart = arrayStart;
    }

    if (jsonStart >= 0) {
      final possiblePrefix = trimmed.substring(0, jsonStart).trim();
      final possibleJson = trimmed.substring(jsonStart).trim();

      try {
        final decoded = jsonDecode(possibleJson);
        final yaml = _toYaml(decoded);
        String? cleanPrefix = possiblePrefix;
        if (cleanPrefix.startsWith('<<<') || cleanPrefix.startsWith('>>>')) {
          cleanPrefix = cleanPrefix
              .replaceFirst(RegExp(r'^(<<<|>>>)\s*'), '')
              .replaceFirst(RegExp(r':$'), '')
              .trim();
        }
        if (cleanPrefix.isEmpty) cleanPrefix = null;

        return FormattedLogMessage(
          prefix: cleanPrefix,
          content: yaml,
          isStructured: true,
          raw: raw,
        );
      } catch (_) {
        // Not valid JSON, fall back to plain display
      }
    }

    return FormattedLogMessage(
      prefix: null,
      content: raw,
      isStructured: false,
      raw: raw,
    );
  }

  /// Formats a decoded JSON object (Map, List, primitive) into a clean YAML string.
  static String _toYaml(dynamic object, {int indent = 0}) {
    final spaces = '  ' * indent;

    if (object is Map) {
      if (object.isEmpty) return '{}';
      final buffer = StringBuffer();
      var first = true;
      for (final entry in object.entries) {
        if (!first) buffer.writeln();
        first = false;
        final key = entry.key.toString();
        final val = entry.value;

        buffer.write('$spaces$key:');
        if (val is Map) {
          if (val.isEmpty) {
            buffer.write(' {}');
          } else {
            buffer.writeln();
            buffer.write(_toYaml(val, indent: indent + 1));
          }
        } else if (val is List) {
          if (val.isEmpty) {
            buffer.write(' []');
          } else {
            buffer.writeln();
            buffer.write(_toYaml(val, indent: indent + 1));
          }
        } else {
          buffer.write(' ${_formatScalar(val)}');
        }
      }
      return buffer.toString();
    } else if (object is List) {
      if (object.isEmpty) return '[]';
      final buffer = StringBuffer();
      var first = true;
      for (final item in object) {
        if (!first) buffer.writeln();
        first = false;

        buffer.write('$spaces-');
        if (item is Map) {
          if (item.isEmpty) {
            buffer.write(' {}');
          } else {
            final mapYaml = _toYaml(item, indent: indent + 1);
            final lines = mapYaml.split('\n');
            if (lines.isNotEmpty) {
              buffer.write(' ${lines.first.trimLeft()}');
              for (int i = 1; i < lines.length; i++) {
                buffer.writeln();
                buffer.write(lines[i]);
              }
            }
          }
        } else if (item is List) {
          buffer.writeln();
          buffer.write(_toYaml(item, indent: indent + 1));
        } else {
          buffer.write(' ${_formatScalar(item)}');
        }
      }
      return buffer.toString();
    } else {
      return _formatScalar(object);
    }
  }

  static String _formatScalar(dynamic value) {
    if (value == null) return 'null';
    if (value is num || value is bool) return value.toString();
    final str = value.toString();
    if (str.isEmpty) return '""';
    // Quote string if it contains special yaml characters or newlines
    if (str.contains('\n') ||
        str.contains(':') ||
        str.contains('#') ||
        str.contains('{') ||
        str.contains('}') ||
        str.contains('[') ||
        str.contains(']') ||
        str.startsWith('-') ||
        RegExp(r'^(true|false|null|\d+)$').hasMatch(str)) {
      return '"${str.replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
    }
    return str;
  }

  /// Highlights a YAML string with syntax colors suitable for the current theme.
  static TextSpan buildSyntaxHighlightedSpan(
    String yaml,
    BuildContext context, {
    double fontSize = 11,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Syntax colors
    final keyColor = isDark
        ? const Color(0xFF64D2FF)
        : const Color(0xFF0066CC); // Cyan/Blue
    final stringColor = isDark
        ? const Color(0xFF98E586)
        : const Color(0xFF1E8238); // Green
    final numberColor = isDark
        ? const Color(0xFFFFB86C)
        : const Color(0xFFB54708); // Amber/Orange
    final boolNullColor = isDark
        ? const Color(0xFFFF79C6)
        : const Color(0xFF9333EA); // Magenta/Purple
    final bulletColor = isDark
        ? const Color(0xFFBD93F9)
        : const Color(0xFF7C3AED); // Lavender
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    final lines = yaml.split('\n');
    final lineSpans = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final spans = <TextSpan>[];

      // Match indentation
      final leadingSpacesMatch = RegExp(r'^(\s*)').firstMatch(line);
      final leadingSpaces = leadingSpacesMatch?.group(1) ?? '';
      if (leadingSpaces.isNotEmpty) {
        spans.add(TextSpan(text: leadingSpaces));
      }

      var rest = line.substring(leadingSpaces.length);

      // Match bullet '-'
      if (rest.startsWith('-')) {
        spans.add(
          TextSpan(
            text: '- ',
            style: TextStyle(color: bulletColor, fontWeight: FontWeight.bold),
          ),
        );
        rest = rest.length > 1 ? rest.substring(1).trimLeft() : '';
      }

      // Match "key:"
      final keyMatch = RegExp(r'^([a-zA-Z0-9_.\-]+):(\s*)').firstMatch(rest);
      if (keyMatch != null) {
        final keyText = keyMatch.group(1)!;
        final colonSpacing = keyMatch.group(2)!;
        spans.add(
          TextSpan(
            text: '$keyText:',
            style: TextStyle(color: keyColor, fontWeight: FontWeight.w600),
          ),
        );
        if (colonSpacing.isNotEmpty) {
          spans.add(TextSpan(text: colonSpacing));
        }
        rest = rest.substring(keyMatch.end);
      }

      // Value formatting
      if (rest.isNotEmpty) {
        if (rest.startsWith('"') && rest.endsWith('"')) {
          spans.add(
            TextSpan(
              text: rest,
              style: TextStyle(color: stringColor),
            ),
          );
        } else if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(rest)) {
          spans.add(
            TextSpan(
              text: rest,
              style: TextStyle(color: numberColor, fontWeight: FontWeight.w500),
            ),
          );
        } else if (rest == 'true' || rest == 'false' || rest == 'null') {
          spans.add(
            TextSpan(
              text: rest,
              style: TextStyle(
                color: boolNullColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: rest,
              style: TextStyle(color: defaultColor),
            ),
          );
        }
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }

      lineSpans.addAll(spans);
    }

    return TextSpan(
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        height: 1.4,
      ),
      children: lineSpans,
    );
  }
}
