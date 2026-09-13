/// Role of the message sender in the conversation.
enum MessageRole {
  user,
  assistant,
  system,
}

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

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thoughts,
    this.isStreaming = false,
    this.isThinking = false,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;

  bool get hasThoughts => thoughts != null && thoughts!.trim().isNotEmpty;
}
