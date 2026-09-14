import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:genui/genui.dart' hide ChatMessage;

import '../models/chat_message.dart';
import '../services/antigravity_service.dart';
import 'process_log_panel.dart';
import 'settings_dialog.dart';

/// Main interactive chat screen for Antigravity.
class ChatScreen extends StatefulWidget {
  final AntigravityService service;
  final List<ChatMessage>? initialMessages;

  const ChatScreen({super.key, required this.service, this.initialMessages});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<ChatMessage> _messages;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final Ticker _scrollTicker;
  Duration _lastTick = Duration.zero;
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessages != null) {
      _messages = List<ChatMessage>.from(widget.initialMessages!);
      widget.service.restoreGenUiSurfaces(_messages);
    } else {
      _messages = widget.service.loadPersistedMessages();
    }
    _scrollTicker = createTicker(_onScrollTick);
    widget.service.addListener(_onServiceChanged);
    widget.service.onUiActionSubmitted = _onUiActionSubmitted;
  }

  @override
  void dispose() {
    widget.service.onUiActionSubmitted = null;
    widget.service.removeListener(_onServiceChanged);
    _scrollTicker.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onUiActionSubmitted(String actionPrompt) {
    if (!mounted || widget.service.isGenerating) return;
    _sendMessage(actionPrompt);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _onScrollTick(Duration elapsed) {
    if (!mounted || !_scrollController.hasClients) return;

    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    final clampedDt = dt.clamp(0.001, 0.05);

    // If the user intentionally scrolled up, pause automatic following
    if (_userScrolledUp) {
      if (!widget.service.isGenerating && _scrollTicker.isActive) {
        _stopScrollTicker();
      }
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final remaining = maxExtent - current;

    if (remaining > 0.5) {
      // Fluid continuous advance: smoothly tracks scroll extent with damping
      final followFactor = 1.0 - math.exp(-12.0 * clampedDt);
      final step = (remaining * followFactor).clamp(0.0, remaining);
      _scrollController.jumpTo(current + step);
    } else {
      if (current != maxExtent) {
        _scrollController.jumpTo(maxExtent);
      }
      if (!widget.service.isGenerating) {
        _stopScrollTicker();
      }
    }
  }

  void _startScrollTicker() {
    if (!_scrollTicker.isActive) {
      _lastTick = Duration.zero;
      _scrollTicker.start();
    }
  }

  void _stopScrollTicker() {
    if (_scrollTicker.isActive) {
      _scrollTicker.stop();
      _lastTick = Duration.zero;
    }
  }

  void _requestScrollFollow() {
    if (!_userScrolledUp) {
      _startScrollTicker();
    }
  }

  void _scrollToBottomAndResume() {
    setState(() => _userScrolledUp = false);
    _startScrollTicker();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || widget.service.isGenerating) return;

    _textController.clear();

    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: text,
    );

    final botMsgId = (DateTime.now().microsecondsSinceEpoch + 1).toString();
    final botMsg = ChatMessage(
      id: botMsgId,
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
      isThinking: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(botMsg);
      _userScrolledUp = false;
    });
    widget.service.persistMessages(_messages);
    _startScrollTicker();

    await widget.service.sendMessage(
      prompt: text,
      onSurfaceAdded: (surfaceId) {
        if (!mounted) return;
        setState(() {
          if (!botMsg.surfaceIds.contains(surfaceId)) {
            botMsg.surfaceIds.add(surfaceId);
          }
        });
        widget.service.persistMessages(_messages);
        _requestScrollFollow();
      },
      onToken: (token) {
        if (!mounted) return;
        setState(() {
          botMsg.isThinking = false;
          botMsg.content += token;
        });
        _requestScrollFollow();
      },
      onThought: (thought) {
        if (!mounted) return;
        setState(() {
          botMsg.thoughts = (botMsg.thoughts ?? '') + thought;
        });
        _requestScrollFollow();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          botMsg.isStreaming = false;
          botMsg.isThinking = false;
          botMsg.error = err;
        });
        widget.service.persistMessages(_messages);
        _requestScrollFollow();
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          botMsg.isStreaming = false;
          botMsg.isThinking = false;
        });
        widget.service.persistMessages(_messages);
        _requestScrollFollow();
      },
    );
  }

  void _insertNewline() {
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0 && end >= 0) {
      final newText = text.replaceRange(start, end, '\n');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 1),
      );
    } else {
      final newText = '$text\n';
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _clearChat() {
    _stopScrollTicker();
    setState(() {
      _messages.clear();
      _userScrolledUp = false;
    });
    widget.service.clearSession();
  }

  void _exportConversation() {
    final markdown = widget.service.exportConversationMarkdown(_messages);
    showDialog(
      context: context,
      builder: (ctx) => _ExportDialog(markdown: markdown),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        width: math.min(480, math.max(320, screenWidth * 0.45)),
        child: SafeArea(
          child: ProcessLogPanel(
            service: widget.service,
            onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
          ),
        ),
      ),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Antigravity Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.service.model,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Subprocess trace',
            icon: const Icon(Icons.terminal),
            onPressed: () {
              if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                _scaffoldKey.currentState?.closeEndDrawer();
              } else {
                _scaffoldKey.currentState?.openEndDrawer();
              }
            },
          ),
          IconButton(
            tooltip: 'Export conversation',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _messages.isEmpty ? null : _exportConversation,
          ),
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => SettingsDialog.show(context, widget.service),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (widget.service.lastError != null)
            _buildErrorBanner(widget.service.lastError!),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(colorScheme)
                : Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is UserScrollNotification) {
                            if (notification.direction ==
                                ScrollDirection.forward) {
                              // User is scrolling upwards towards older messages
                              if (!_userScrolledUp) {
                                setState(() => _userScrolledUp = true);
                              }
                            } else if (notification.direction ==
                                ScrollDirection.reverse) {
                              // User is scrolling downwards towards latest messages
                              if (_scrollController.hasClients &&
                                  _scrollController.position.extentAfter < 24) {
                                if (_userScrolledUp) {
                                  setState(() => _userScrolledUp = false);
                                  _startScrollTicker();
                                }
                              }
                            }
                          } else if (notification is ScrollUpdateNotification) {
                            // Detect user direct dragging
                            if (notification.dragDetails != null &&
                                _scrollController.hasClients &&
                                _scrollController.position.extentAfter > 50) {
                              if (!_userScrolledUp) {
                                setState(() => _userScrolledUp = true);
                              }
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _MessageBubble(
                              message: message,
                              service: widget.service,
                            );
                          },
                        ),
                      ),
                      if (_userScrolledUp)
                        Positioned(
                          bottom: 16,
                          right: 24,
                          child: FloatingActionButton.small(
                            heroTag: 'scrollToBottomBtn',
                            tooltip: 'Scroll to bottom',
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.primary,
                            elevation: 3,
                            onPressed: _scrollToBottomAndResume,
                            child: widget.service.isGenerating
                                ? Badge(
                                    smallSize: 8,
                                    backgroundColor: colorScheme.primary,
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                    ),
                                  )
                                : const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                  ),
                          ),
                        ),
                    ],
                  ),
          ),
          _buildInputBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.15,
              ),
              foregroundColor: colorScheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.tune, size: 16),
            label: const Text(
              'Settings',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => SettingsDialog.show(context, widget.service),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 16),
            color: colorScheme.onErrorContainer,
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.service.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to Antigravity',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation with your local Antigravity agent.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.quiz_outlined, size: 16),
                    label: const Text('Multiple choice question (GenUI)'),
                    onPressed: () => _sendMessage(
                      'Ask me a multiple choice question with 3 options using the MultipleChoiceQuestion GenUI component',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.code, size: 16),
                    label: const Text('Write a Flutter widget'),
                    onPressed: () =>
                        _sendMessage('Write an animated Flutter button widget'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.check_circle_outlined, size: 16),
                    label: const Text('Confirmation card (GenUI)'),
                    onPressed: () => _sendMessage(
                      'Ask me to confirm running a database migration using the ConfirmationCard GenUI component',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.star_outline_rounded, size: 16),
                    label: const Text('Feedback rating (GenUI)'),
                    onPressed: () => _sendMessage(
                      'Ask for my feedback on your assistance using the FeedbackRatingCard GenUI component',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.science, size: 16),
                    label: const Text('Explain quantum gravity'),
                    onPressed: () =>
                        _sendMessage('Explain quantum gravity simply'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 16),
                    label: const Text('What tools do you have?'),
                    onPressed: () => _sendMessage(
                      'What tools and capabilities do you have?',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    final isGenerating = widget.service.isGenerating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    _sendMessage();
                  },
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                    _sendMessage();
                  },
                  const SingleActivator(
                    LogicalKeyboardKey.enter,
                    shift: true,
                  ): () {
                    _insertNewline();
                  },
                  const SingleActivator(
                    LogicalKeyboardKey.numpadEnter,
                    shift: true,
                  ): () {
                    _insertNewline();
                  },
                },
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message Antigravity... (Enter to send, Shift+Enter for newline)',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isGenerating)
              IconButton.filled(
                tooltip: 'Stop generation',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                icon: const Icon(Icons.stop),
                onPressed: () => widget.service.cancelGeneration(),
              )
            else
              IconButton.filled(
                tooltip: 'Send message',
                icon: const Icon(Icons.arrow_upward),
                onPressed: () => _sendMessage(),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final AntigravityService? service;

  const _MessageBubble({required this.message, this.service});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showThoughts = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = widget.message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thoughts / Reasoning section
                  if (widget.message.hasThoughts) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() => _showThoughts = !_showThoughts);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Thinking Process',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showThoughts
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showThoughts) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: MarkdownBody(
                          data: widget.message.thoughts!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme)
                              .copyWith(
                                p: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                em: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                strong: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                code: TextStyle(
                                  backgroundColor: colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.7),
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],

                  // Main message content
                  Builder(
                    builder: (context) {
                      final displayContent = widget.message.displayContent;
                      if (displayContent.isNotEmpty) {
                        return isUser
                            ? SelectableText(
                                displayContent,
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 14,
                                ),
                              )
                            : MarkdownBody(
                                data: displayContent,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                    .copyWith(
                                      p: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                      code: TextStyle(
                                        backgroundColor: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.7),
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                              );
                      } else if (widget.message.isStreaming &&
                          !widget.message.hasSurfaces) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.message.isThinking
                                  ? 'Thinking...'
                                  : 'Generating...',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Dynamic GenUI Surfaces
                  if (widget.message.hasSurfaces && widget.service != null) ...[
                    const SizedBox(height: 10),
                    ...widget.message.surfaceIds.map((surfaceId) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Surface(
                            surfaceContext: widget.service!.surfaceController
                                .contextFor(surfaceId),
                          ),
                        ),
                      );
                    }),
                  ],

                  // Error alert if message failed
                  if (widget.message.error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.message.error!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportDialog extends StatelessWidget {
  final String markdown;

  const _ExportDialog({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.description_outlined),
          SizedBox(width: 8),
          Text('Export Conversation'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview formatted Markdown conversation:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: BoxConstraints(
                  maxHeight: math.min(
                    300.0,
                    MediaQuery.sizeOf(context).height * 0.45,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    markdown,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy Markdown'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: markdown));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conversation copied to clipboard as Markdown'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
