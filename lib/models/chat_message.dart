/// Role of the message sender in the conversation.
enum MessageRole { user, assistant, system }

/// Represents a single message in the chat conversation.
class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  String? thoughts;
  bool isStreaming;
  bool isThinking;
  String? error;
  final DateTime timestamp;
  final List<String> surfaceIds;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thoughts,
    this.isStreaming = false,
    this.isThinking = false,
    this.error,
    DateTime? timestamp,
    List<String>? surfaceIds,
  }) : timestamp = timestamp ?? DateTime.now(),
       surfaceIds = surfaceIds ?? <String>[];

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;

  bool get hasThoughts => thoughts != null && thoughts!.trim().isNotEmpty;
  bool get hasSurfaces => surfaceIds.isNotEmpty;

  /// Returns the content formatted for display, stripping raw A2UI JSON protocol
  /// code blocks when dynamic surfaces have been rendered.
  String get displayContent {
    if (!hasSurfaces) return content;
    final a2uiRegex = RegExp(
      r'```(?:json)?\s*\{[\s\S]*?"(?:createSurface|updateComponents|version)"[\s\S]*?\}\s*```',
      multiLine: true,
    );
    return content.replaceAll(a2uiRegex, '').trim();
  }

  /// Converts this message to a JSON map suitable for persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'thoughts': thoughts,
    'error': error,
    'timestamp': timestamp.toIso8601String(),
    'surfaceIds': surfaceIds,
  };

  /// Constructs a [ChatMessage] from a JSON map.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.byName(json['role'] as String),
      content: (json['content'] as String?) ?? '',
      thoughts: json['thoughts'] as String?,
      error: json['error'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      surfaceIds: (json['surfaceIds'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isStreaming: false,
      isThinking: false,
    );
  }

  /// Formats this message into Markdown with role header, timestamp, and optional thinking trace.
  String toMarkdown() {
    final buffer = StringBuffer();
    final roleName = isUser
        ? 'User'
        : isAssistant
        ? 'Assistant'
        : 'System';
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    buffer.writeln('### $roleName ($timeStr)\n');

    if (hasThoughts) {
      buffer.writeln('> **Thinking Process:**');
      for (final line in thoughts!.trim().split('\n')) {
        buffer.writeln('> $line');
      }
      buffer.writeln();
    }

    final text = displayContent.trim();
    if (text.isNotEmpty) {
      buffer.writeln(text);
    }

    if (error != null && error!.isNotEmpty) {
      buffer.writeln('\n**Error:** `$error`');
    }

    return buffer.toString();
  }
}
