import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _feedbackRatingSchema = S.object(
  description: 'A card soliciting numerical rating (1-5 stars) and optional feedback comments from the user.',
  properties: {
    'prompt': S.string(
      description: 'The prompt or question asking for feedback.',
    ),
    'maxRating': S.integer(
      description: 'The maximum rating score on the scale. Defaults to 5.',
    ),
    'allowFeedbackText': S.boolean(
      description:
          'Whether to show a text area for written comments. Defaults to true.',
    ),
    'submitLabel': S.string(
      description:
          'Text for the submission button. Defaults to "Submit Feedback".',
    ),
  },
  required: ['prompt'],
);

extension type _FeedbackData.fromMap(JsonMap _json) {
  String get prompt =>
      (_json['prompt'] as String?) ?? 'Please rate your experience:';

  int get maxRating => (_json['maxRating'] as num?)?.toInt() ?? 5;

  bool get allowFeedbackText => (_json['allowFeedbackText'] as bool?) ?? true;

  String get submitLabel =>
      (_json['submitLabel'] as String?) ?? 'Submit Feedback';
}

/// A GenUI [CatalogItem] that renders an interactive rating and feedback card.
final feedbackRatingCardItem = CatalogItem(
  name: 'FeedbackRatingCard',
  dataSchema: _feedbackRatingSchema,
  widgetBuilder: (itemContext) {
    final data = _FeedbackData.fromMap(itemContext.data as JsonMap);
    return _FeedbackRatingCardWidget(itemContext: itemContext, data: data);
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "FeedbackRatingCard",
          "prompt": "How helpful was this code generation?",
          "maxRating": 5,
          "allowFeedbackText": true,
          "submitLabel": "Send Rating"
        }
      ]
    ''',
  ],
);

class _FeedbackRatingCardWidget extends StatefulWidget {
  final CatalogItemContext itemContext;
  final _FeedbackData data;

  const _FeedbackRatingCardWidget({
    required this.itemContext,
    required this.data,
  });

  @override
  State<_FeedbackRatingCardWidget> createState() =>
      _FeedbackRatingCardWidgetState();
}

class _FeedbackRatingCardWidgetState extends State<_FeedbackRatingCardWidget> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0 || _isSubmitted) return;

    setState(() {
      _isSubmitted = true;
    });

    final comment = _commentController.text.trim();

    widget.itemContext.dispatchEvent(
      UserActionEvent(
        name: 'feedback_submitted',
        sourceComponentId: widget.itemContext.id,
        context: {
          'prompt': widget.data.prompt,
          'rating': _rating,
          'maxRating': widget.data.maxRating,
          'comment': comment.isNotEmpty ? comment : null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxStars = widget.data.maxRating;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Star icon + Prompt
            Row(
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.prompt,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Star rating selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(maxStars, (index) {
                final starNumber = index + 1;
                final isFilled = starNumber <= _rating;

                return Tooltip(
                  message: '$starNumber of $maxStars stars',
                  child: InkWell(
                    onTap: _isSubmitted
                        ? null
                        : () {
                            setState(() {
                              _rating = starNumber;
                            });
                          },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Icon(
                        isFilled
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 28,
                        color: isFilled
                            ? Colors.amber
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Optional feedback comment box (only when interactive)
            if (widget.data.allowFeedbackText && !_isSubmitted) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Additional feedback (optional)...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            // Submission button (before submit)
            if (!_isSubmitted) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(widget.data.submitLabel),
                  onPressed: _rating > 0 ? _submit : null,
                ),
              ),
            ] else ...[
              // Post-submit confirmation badge
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thank you for your feedback! ($_rating/$maxStars stars)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
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
    );
  }
}
