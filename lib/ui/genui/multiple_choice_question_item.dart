import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _multipleChoiceQuestionSchema = S.object(
  description: 'A card presenting a multiple-choice question to the user, with an automatic write-in "Other" option.',
  properties: {
    'question': S.string(description: 'The question text to ask the user.'),
    'options': S.list(
      items: S.string(),
      description: 'List of option choices for the user to choose from.',
    ),
    'allowMultiple': S.boolean(
      description: 'Whether multiple options can be chosen simultaneously. Defaults to false.',
    ),
    'submitLabel': S.string(
      description: 'The label for the submission button. Defaults to "Submit".',
    ),
  },
  required: ['question', 'options'],
);

extension type _QuestionData.fromMap(JsonMap _json) {
  String get question => (_json['question'] as String?) ?? '';

  List<String> get options {
    final raw = _json['options'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  bool get allowMultiple => (_json['allowMultiple'] as bool?) ?? false;

  String get submitLabel =>
      (_json['submitLabel'] as String?) ?? 'Submit Answer';
}

/// A GenUI [CatalogItem] that renders an interactive multiple-choice question card.
/// It always automatically appends an "Other (write your own)" option with a text field.
final multipleChoiceQuestionItem = CatalogItem(
  name: 'MultipleChoiceQuestion',
  dataSchema: _multipleChoiceQuestionSchema,
  widgetBuilder: (itemContext) {
    final data = _QuestionData.fromMap(itemContext.data as JsonMap);
    return _MultipleChoiceQuestionWidget(itemContext: itemContext, data: data);
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "MultipleChoiceQuestion",
          "question": "Which platform are you targeting first?",
          "options": ["Android", "iOS", "Web", "macOS", "Windows", "Linux"],
          "allowMultiple": false
        }
      ]
    ''',
  ],
);

class _MultipleChoiceQuestionWidget extends StatefulWidget {
  final CatalogItemContext itemContext;
  final _QuestionData data;

  const _MultipleChoiceQuestionWidget({
    required this.itemContext,
    required this.data,
  });

  @override
  State<_MultipleChoiceQuestionWidget> createState() =>
      _MultipleChoiceQuestionWidgetState();
}

class _MultipleChoiceQuestionWidgetState
    extends State<_MultipleChoiceQuestionWidget> {
  final Set<String> _selectedOptions = <String>{};
  bool _isOtherSelected = false;
  final TextEditingController _otherController = TextEditingController();
  final FocusNode _otherFocusNode = FocusNode();
  bool _isSubmitted = false;
  String? _submittedSummary;

  @override
  void initState() {
    super.initState();
    _otherController.addListener(_onOtherTextChanged);
  }

  @override
  void dispose() {
    _otherController.removeListener(_onOtherTextChanged);
    _otherController.dispose();
    _otherFocusNode.dispose();
    super.dispose();
  }

  void _onOtherTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    if (_isSubmitted) return false;
    final hasStandardSelection = _selectedOptions.isNotEmpty;
    final hasValidOther =
        _isOtherSelected && _otherController.text.trim().isNotEmpty;

    if (widget.data.allowMultiple) {
      return hasStandardSelection || hasValidOther;
    } else {
      if (_isOtherSelected) {
        return hasValidOther;
      }
      return hasStandardSelection;
    }
  }

  void _selectSingleOption(String option) {
    if (_isSubmitted) return;
    setState(() {
      _selectedOptions.clear();
      _selectedOptions.add(option);
      _isOtherSelected = false;
    });
  }

  void _selectOtherOption() {
    if (_isSubmitted) return;
    setState(() {
      if (!widget.data.allowMultiple) {
        _selectedOptions.clear();
      }
      _isOtherSelected = true;
    });
    Future.microtask(() {
      if (mounted) _otherFocusNode.requestFocus();
    });
  }

  void _toggleMultipleOption(String option, bool? selected) {
    if (_isSubmitted) return;
    setState(() {
      if (selected == true) {
        _selectedOptions.add(option);
      } else {
        _selectedOptions.remove(option);
      }
    });
  }

  void _toggleMultipleOther(bool? selected) {
    if (_isSubmitted) return;
    setState(() {
      _isOtherSelected = selected == true;
    });
    if (_isOtherSelected) {
      Future.microtask(() {
        if (mounted) _otherFocusNode.requestFocus();
      });
    }
  }

  void _submitAnswer() {
    if (!_canSubmit) return;

    final List<String> finalAnswers = [
      ..._selectedOptions,
      if (_isOtherSelected && _otherController.text.trim().isNotEmpty)
        'Other: ${_otherController.text.trim()}',
    ];

    final summary = finalAnswers.join(', ');

    setState(() {
      _isSubmitted = true;
      _submittedSummary = summary;
    });

    widget.itemContext.dispatchEvent(
      UserActionEvent(
        name: 'answer_submitted',
        sourceComponentId: widget.itemContext.id,
        context: {
          'question': widget.data.question,
          'answer': summary,
          'selectedOptions': finalAnswers,
          'isOther': _isOtherSelected,
          'customAnswer': _isOtherSelected
              ? _otherController.text.trim()
              : null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final options = widget.data.options;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Icon + Question Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.quiz_outlined,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.data.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Options List
            if (widget.data.allowMultiple) ...[
              for (final option in options)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  enabled: !_isSubmitted,
                  title: Text(option, style: const TextStyle(fontSize: 14)),
                  value: _selectedOptions.contains(option),
                  onChanged: (val) => _toggleMultipleOption(option, val),
                ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                enabled: !_isSubmitted,
                title: const Text(
                  'Other (write your own answer)',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
                value: _isOtherSelected,
                onChanged: _toggleMultipleOther,
              ),
            ] else ...[
              RadioGroup<String?>(
                groupValue: _isOtherSelected
                    ? '__other__'
                    : _selectedOptions.firstOrNull,
                onChanged: (val) {
                  if (val == '__other__') {
                    _selectOtherOption();
                  } else if (val != null) {
                    _selectSingleOption(val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<String?>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        enabled: !_isSubmitted,
                        title: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: option,
                      ),
                    RadioListTile<String?>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      enabled: !_isSubmitted,
                      title: const Text(
                        'Other (write your own answer)',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      value: '__other__',
                    ),
                  ],
                ),
              ),
            ],

            // Write-in Text Field when "Other" is active
            if (_isOtherSelected && !_isSubmitted) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32, right: 8, bottom: 8),
                child: TextField(
                  controller: _otherController,
                  focusNode: _otherFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type your custom answer here...',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
                    prefixIcon: const Icon(Icons.edit_note, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Footer: Submit Button or Submitted Confirmation
            if (_isSubmitted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Submitted: ${_submittedSummary ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _canSubmit ? _submitAnswer : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(widget.data.submitLabel),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
