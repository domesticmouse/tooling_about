import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _confirmationCardSchema = S.object(
  description: 'A card asking the user to confirm, approve, or reject an action or tool call.',
  properties: {
    'title': S.string(
      description: 'The title of the action requiring confirmation.',
    ),
    'description': S.string(
      description: 'Detailed explanation of what the action entails.',
    ),
    'details': S.string(
      description:
          'Optional technical details, code command, file path, or payload.',
    ),
    'confirmLabel': S.string(
      description: 'Text for the confirm button. Defaults to "Approve".',
    ),
    'cancelLabel': S.string(
      description: 'Text for the cancel button. Defaults to "Reject".',
    ),
    'isDestructive': S.boolean(
      description: 'If true, the action deletes data or is risky (highlights confirm button red). Defaults to false.',
    ),
  },
  required: ['title', 'description'],
);

extension type _ConfirmationData.fromMap(JsonMap _json) {
  String get title => (_json['title'] as String?) ?? 'Action Confirmation';

  String get description => (_json['description'] as String?) ?? '';

  String? get details => _json['details'] as String?;

  String get confirmLabel => (_json['confirmLabel'] as String?) ?? 'Approve';

  String get cancelLabel => (_json['cancelLabel'] as String?) ?? 'Reject';

  bool get isDestructive => (_json['isDestructive'] as bool?) ?? false;
}

/// A GenUI [CatalogItem] that renders an interactive confirmation / approval card.
final confirmationCardItem = CatalogItem(
  name: 'ConfirmationCard',
  dataSchema: _confirmationCardSchema,
  widgetBuilder: (itemContext) {
    final data = _ConfirmationData.fromMap(itemContext.data as JsonMap);
    return _ConfirmationCardWidget(itemContext: itemContext, data: data);
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "ConfirmationCard",
          "title": "Deploy to Staging",
          "description": "The agent is about to trigger a staging deployment.",
          "details": "git push staging main && deploy-service --env=staging",
          "confirmLabel": "Deploy Now",
          "cancelLabel": "Cancel",
          "isDestructive": false
        }
      ]
    ''',
  ],
);

class _ConfirmationCardWidget extends StatefulWidget {
  final CatalogItemContext itemContext;
  final _ConfirmationData data;

  const _ConfirmationCardWidget({
    required this.itemContext,
    required this.data,
  });

  @override
  State<_ConfirmationCardWidget> createState() =>
      _ConfirmationCardWidgetState();
}

class _ConfirmationCardWidgetState extends State<_ConfirmationCardWidget> {
  bool _hasResponded = false;
  bool? _isConfirmed;

  void _respond(bool confirmed) {
    if (_hasResponded) return;

    setState(() {
      _hasResponded = true;
      _isConfirmed = confirmed;
    });

    final actionText = confirmed ? 'Approved' : 'Rejected';

    widget.itemContext.dispatchEvent(
      UserActionEvent(
        name: 'confirmation_response',
        sourceComponentId: widget.itemContext.id,
        context: {
          'title': widget.data.title,
          'confirmed': confirmed,
          'action': actionText,
          if (widget.data.details != null) 'details': widget.data.details,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDestructive = widget.data.isDestructive;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDestructive
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
          width: isDestructive ? 1.5 : 1.0,
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Icon + Title + (Status Badge if responded)
            Row(
              children: [
                Icon(
                  isDestructive
                      ? Icons.warning_amber_rounded
                      : Icons.shield_outlined,
                  size: 20,
                  color: isDestructive
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDestructive
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_hasResponded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isConfirmed == true
                          ? Colors.green.withValues(alpha: 0.15)
                          : colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isConfirmed == true
                            ? Colors.green
                            : colorScheme.error,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isConfirmed == true ? Icons.check : Icons.close,
                          size: 14,
                          color: _isConfirmed == true
                              ? Colors.green
                              : colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isConfirmed == true ? 'Approved' : 'Rejected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isConfirmed == true
                                ? Colors.green
                                : colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              widget.data.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Optional Details / Command box
            if (widget.data.details != null &&
                widget.data.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SelectableText(
                  widget.data.details!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            // Action buttons (only interactive before response)
            if (!_hasResponded) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _respond(false),
                    child: Text(widget.data.cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: isDestructive
                        ? FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                          )
                        : null,
                    onPressed: () => _respond(true),
                    child: Text(widget.data.confirmLabel),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
