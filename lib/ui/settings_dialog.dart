import 'package:flutter/material.dart';

import '../services/antigravity_service.dart';

/// Dialog for configuring Antigravity agent settings.
class SettingsDialog extends StatefulWidget {
  final AntigravityService service;

  const SettingsDialog({super.key, required this.service});

  static Future<void> show(BuildContext context, AntigravityService service) {
    return showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(service: service),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _apiKeyController;
  late TextEditingController _systemInstructionsController;
  late String _selectedModel;
  bool _obscureApiKey = true;

  final List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3.8-flash',
  ];

  @override
  void initState() {
    super.initState();
    // Only display the manually entered custom key in the editable field
    _apiKeyController = TextEditingController(
      text: widget.service.customApiKey ?? '',
    );
    _systemInstructionsController = TextEditingController(
      text: widget.service.systemInstructions,
    );
    _selectedModel = _models.contains(widget.service.model)
        ? widget.service.model
        : _models.first;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _systemInstructionsController.dispose();
    super.dispose();
  }

  void _save() {
    widget.service.updateSettings(
      apiKey: _apiKeyController.text,
      model: _selectedModel,
      systemInstructions: _systemInstructionsController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune),
          SizedBox(width: 8),
          Text('Antigravity Settings'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Model', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _models
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedModel = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  Text('Gemini API Key', style: theme.textTheme.labelLarge),
                  if (widget.service.isUsingEnvironmentApiKey)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco,
                            size: 13,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Using GEMINI_API_KEY from environment',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.service.customApiKey != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 13,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Custom key stored',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: widget.service.environmentApiKey != null
                      ? 'Environment key active. Enter key here to override.'
                      : 'Enter custom API key (or set GEMINI_API_KEY env var)',
                  helperText: widget.service.isUsingEnvironmentApiKey
                      ? 'Active key is supplied by GEMINI_API_KEY environment variable.'
                      : (widget.service.customApiKey != null
                            ? 'Clear this field and save to revert to environment variable.'
                            : null),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('System Instructions', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _systemInstructionsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter persona or system instructions...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save & Apply')),
      ],
    );
  }
}
