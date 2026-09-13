import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/process_log_entry.dart';
import '../services/antigravity_service.dart';
import '../utils/yaml_highlighter.dart';

/// Right-hand scrollable container displaying the trace of all subprocess messages.
class ProcessLogPanel extends StatefulWidget {
  final AntigravityService service;
  final VoidCallback? onClose;

  const ProcessLogPanel({super.key, required this.service, this.onClose});

  @override
  State<ProcessLogPanel> createState() => _ProcessLogPanelState();
}

class _ProcessLogPanelState extends State<ProcessLogPanel>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = 'all'; // 'all', 'in', 'out', 'error'
  String _searchQuery = '';

  late final Ticker _scrollTicker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scrollTicker = createTicker(_onScrollTick);
    widget.service.addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onLogsUpdated);
    _scrollTicker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (_autoScroll) {
      _startScrollTicker();
    }
  }

  void _onScrollTick(Duration elapsed) {
    if (!mounted || !_scrollController.hasClients) return;

    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    final clampedDt = dt.clamp(0.001, 0.05);

    if (!_autoScroll) {
      _stopScrollTicker();
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final remaining = maxExtent - current;

    if (remaining > 0.5) {
      // Flow speed is dynamically dependent on the amount of queued content:
      // Speeds up during a burst, then gracefully slows down towards the end,
      // strictly preventing over-running the end of the flow.
      final followFactor = 1.0 - math.exp(-14.0 * clampedDt);
      final step = (remaining * followFactor).clamp(0.0, remaining);
      _scrollController.jumpTo(current + step);
    } else {
      if (current != maxExtent) {
        _scrollController.jumpTo(maxExtent);
      }
      _stopScrollTicker();
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

  List<ProcessLogEntry> _getFilteredLogs() {
    return widget.service.processLogs.where((entry) {
      if (_filter == 'in' && !entry.isInbound) return false;
      if (_filter == 'out' && !entry.isOutbound) return false;
      if (_filter == 'error' && !entry.isError) return false;

      if (_searchQuery.isNotEmpty) {
        return entry.message.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (entry.loggerName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredLogs = _getFilteredLogs();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          // Panel Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Subprocess Trace',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.service.processLogs.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(4),
                  tooltip: _autoScroll
                      ? 'Auto-scroll enabled'
                      : 'Auto-scroll disabled',
                  icon: Icon(
                    _autoScroll ? Icons.arrow_downward : Icons.pause,
                    size: 18,
                    color: _autoScroll
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                      if (_autoScroll) {
                        _startScrollTicker();
                      } else {
                        _stopScrollTicker();
                      }
                    });
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(4),
                  tooltip: 'Clear trace',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  onPressed: widget.service.processLogs.isEmpty
                      ? null
                      : () {
                          _stopScrollTicker();
                          widget.service.clearLogs();
                        },
                ),
                if (widget.onClose != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Close trace panel',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildFilterChip('All', 'all', colorScheme),
                    const SizedBox(width: 6),
                    _buildFilterChip('In (<<<)', 'in', colorScheme),
                    const SizedBox(width: 6),
                    _buildFilterChip('Out (>>>)', 'out', colorScheme),
                    const SizedBox(width: 6),
                    _buildFilterChip('Errors', 'error', colorScheme),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: TextField(
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search trace logs...',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 14),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
          ),

          // Log entries list
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No subprocess messages',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is UserScrollNotification) {
                        if (notification.direction == ScrollDirection.forward) {
                          // User scrolled upwards, pause auto-scrolling
                          if (_autoScroll) {
                            setState(() => _autoScroll = false);
                            _stopScrollTicker();
                          }
                        } else if (notification.direction ==
                            ScrollDirection.reverse) {
                          // User scrolled downwards near bottom, resume auto-scrolling
                          if (_scrollController.hasClients &&
                              _scrollController.position.extentAfter < 20) {
                            if (!_autoScroll) {
                              setState(() => _autoScroll = true);
                              _startScrollTicker();
                            }
                          }
                        }
                      } else if (notification is ScrollUpdateNotification) {
                        if (notification.dragDetails != null &&
                            _scrollController.hasClients &&
                            _scrollController.position.extentAfter > 40) {
                          if (_autoScroll) {
                            setState(() => _autoScroll = false);
                            _stopScrollTicker();
                          }
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final entry = filteredLogs[index];
                        return _LogEntryTile(entry: entry);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ColorScheme colorScheme) {
    final isSelected = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final ProcessLogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parsed = YamlHighlighter.parse(entry.message);

    Color badgeColor;
    Color textColor;
    String badgeText;
    IconData badgeIcon;

    switch (entry.direction) {
      case LogDirection.inbound:
        badgeColor = Colors.teal.withValues(alpha: 0.2);
        textColor = Colors.tealAccent.shade400;
        badgeText = 'IN <<<';
        badgeIcon = Icons.south_west;
        break;
      case LogDirection.outbound:
        badgeColor = Colors.indigo.withValues(alpha: 0.25);
        textColor = Colors.indigoAccent.shade100;
        badgeText = 'OUT >>>';
        badgeIcon = Icons.north_east;
        break;
      case LogDirection.error:
        badgeColor = colorScheme.errorContainer.withValues(alpha: 0.7);
        textColor = colorScheme.error;
        badgeText = 'ERR';
        badgeIcon = Icons.warning_amber_rounded;
        break;
      case LogDirection.system:
        badgeColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
        textColor = colorScheme.onSurfaceVariant;
        badgeText = 'SYS';
        badgeIcon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: entry.isError
              ? colorScheme.error.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 10, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (parsed.isStructured) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'YAML',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                entry.formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy, size: 13),
                tooltip: parsed.isStructured ? 'Copy YAML' : 'Copy message',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: parsed.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        parsed.isStructured
                            ? 'YAML payload copied to clipboard'
                            : 'Log copied to clipboard',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          if (parsed.prefix != null) ...[
            const SizedBox(height: 6),
            Text(
              parsed.prefix!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: parsed.isStructured
                ? SelectableText.rich(
                    YamlHighlighter.buildSyntaxHighlightedSpan(
                      parsed.content,
                      context,
                    ),
                  )
                : SelectableText(
                    entry.message,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: entry.isError
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
