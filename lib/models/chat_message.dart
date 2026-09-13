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
}
