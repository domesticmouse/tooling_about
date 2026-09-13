import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/process_log_entry.dart';
import '../services/antigravity_service.dart';

/// Right-hand scrollable container displaying the trace of all subprocess messages.
class ProcessLogPanel extends StatefulWidget {
  final AntigravityService service;
  final VoidCallback? onClose;

  const ProcessLogPanel({
    super.key,
    required this.service,
    this.onClose,
  });

  @override
  State<ProcessLogPanel> createState() => _ProcessLogPanelState();
}

class _ProcessLogPanelState extends State<ProcessLogPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = 'all'; // 'all', 'in', 'out', 'error'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onLogsUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  List<ProcessLogEntry> _getFilteredLogs() {
    return widget.service.processLogs.where((entry) {
      if (_filter == 'in' && !entry.isInbound) return false;
      if (_filter == 'out' && !entry.isOutbound) return false;
      if (_filter == 'error' && !entry.isError) return false;

      if (_searchQuery.isNotEmpty) {
        return entry.message
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (entry.loggerName
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
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
                const Text(
                  'Subprocess Trace',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                ),
                IconButton(
                  tooltip: 'Clear trace',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  onPressed: widget.service.processLogs.isEmpty
                      ? null
                      : () => widget.service.clearLogs(),
                ),
                if (widget.onClose != null)
                  IconButton(
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
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final entry = filteredLogs[index];
                      return _LogEntryTile(entry: entry);
                    },
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
            color:
                isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                icon: const Icon(Icons.copy, size: 12),
                tooltip: 'Copy message',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Log copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            entry.message,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: entry.isError ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
