import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:antigravity/antigravity.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/process_log_entry.dart';

/// Service managing the lifecycle of the Google Antigravity [Agent]
/// and capturing a trace of all subprocess communication.
class AntigravityService extends ChangeNotifier {
  static const String prefKeyApiKey = 'antigravity_api_key';
  static const String prefKeyModel = 'antigravity_model';
  static const String prefKeyInstructions = 'antigravity_system_instructions';

  final SharedPreferences? prefs;

  Agent? _agent;
  ChatResponse? _activeResponse;
  Completer<void>? _generationCompleter;

  String _model = 'gemini-3.8-flash';
  String? _customApiKey;
  String? _environmentApiKey;
  String _systemInstructions =
      'You are a helpful, insightful AI assistant running in a desktop Flutter app powered by Google Antigravity.';

  bool _isInitializing = false;
  bool _isGenerating = false;
  String? _lastError;

  final ListQueue<ProcessLogEntry> _processLogs = ListQueue<ProcessLogEntry>();
  final ValueNotifier<int> _logNotifier = ValueNotifier<int>(0);
  StreamSubscription<LogRecord>? _logSubscription;

  AntigravityService({this.prefs, String? environmentApiKey}) {
    // Enable fine-grained logging across the Dart logging hierarchy
    Logger.root.level = Level.ALL;
    _logSubscription = Logger.root.onRecord.listen(_handleLogRecord);

    _initSettings(environmentApiKey: environmentApiKey);

    addLog(
      'Service initialized. Antigravity logging enabled at Level.ALL.',
      direction: LogDirection.system,
    );
  }

  void _initSettings({String? environmentApiKey}) {
    // 1. Model
    final savedModel = prefs?.getString(prefKeyModel);
    if (savedModel != null && savedModel.isNotEmpty) {
      _model = savedModel;
    }

    // 2. System Instructions
    final savedInstructions = prefs?.getString(prefKeyInstructions);
    if (savedInstructions != null && savedInstructions.isNotEmpty) {
      _systemInstructions = savedInstructions;
    }

    // 3. Environment API Key
    if (environmentApiKey != null && environmentApiKey.trim().isNotEmpty) {
      _environmentApiKey = environmentApiKey.trim();
    } else {
      try {
        final envKey = Platform.environment['GEMINI_API_KEY'];
        if (envKey != null && envKey.trim().isNotEmpty) {
          _environmentApiKey = envKey.trim();
        }
      } catch (_) {}
    }

    // 4. Manually entered API Key from preferences
    final savedApiKey = prefs?.getString(prefKeyApiKey);
    if (savedApiKey != null && savedApiKey.trim().isNotEmpty) {
      _customApiKey = savedApiKey.trim();
    }
  }

  String get model => _model;
  String? get customApiKey => _customApiKey;
  String? get environmentApiKey => _environmentApiKey;
  bool get isUsingEnvironmentApiKey =>
      _customApiKey == null && _environmentApiKey != null;
  String? get apiKey => _customApiKey ?? _environmentApiKey;
  String get systemInstructions => _systemInstructions;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;
  bool get isReady => _agent != null && !_isInitializing;
  String? get lastError => _lastError;
  List<ProcessLogEntry> get processLogs => List.unmodifiable(_processLogs);
  ValueListenable<int> get logNotifier => _logNotifier;

  bool get hasApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  void _handleLogRecord(LogRecord record) {
    final msg = record.message;
    LogDirection direction;

    if (msg.startsWith('>>>') ||
        msg.contains('Sending user_input') ||
        msg.contains('Sending tool_response') ||
        msg.contains('Sending halt_request') ||
        msg.contains('Sending automated_trigger')) {
      direction = LogDirection.outbound;
    } else if (msg.startsWith('<<<') ||
        msg.contains('Received WebSocket message') ||
        msg.contains('Tool call requested') ||
        msg.contains('Trajectory state updated')) {
      direction = LogDirection.inbound;
    } else if (record.level >= Level.WARNING ||
        msg.contains('[Harness Stderr]') ||
        record.level == Level.SEVERE) {
      direction = LogDirection.error;
    } else {
      direction = LogDirection.system;
    }

    addLogEntry(
      ProcessLogEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_processLogs.length}',
        timestamp: record.time,
        message: msg,
        direction: direction,
        level: record.level.name,
        loggerName: record.loggerName,
      ),
    );
  }

  void addLog(String message, {required LogDirection direction}) {
    addLogEntry(
      ProcessLogEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_processLogs.length}',
        timestamp: DateTime.now(),
        message: message,
        direction: direction,
        level: 'INFO',
        loggerName: 'app.service',
      ),
    );
  }

  void addLogEntry(ProcessLogEntry entry) {
    _processLogs.add(entry);
    // Keep max 1500 log entries to manage memory with O(1) removals
    if (_processLogs.length > 1500) {
      _processLogs.removeFirst();
    }
    _logNotifier.value++;
  }

  void clearLogs() {
    _processLogs.clear();
    _logNotifier.value++;
  }

  /// Updates settings and recreates the agent session if needed.
  Future<void> updateSettings({
    String? apiKey,
    String? model,
    String? systemInstructions,
  }) async {
    bool needsRestart = false;
    final sp = prefs ?? await SharedPreferences.getInstance();

    if (apiKey != null) {
      final trimmed = apiKey.trim();
      final newCustomKey = trimmed.isEmpty ? null : trimmed;
      if (newCustomKey != _customApiKey) {
        _customApiKey = newCustomKey;
        if (_customApiKey != null) {
          await sp.setString(prefKeyApiKey, _customApiKey!);
        } else {
          await sp.remove(prefKeyApiKey);
        }
        needsRestart = true;
      }
    }

    if (model != null && model != _model) {
      _model = model;
      await sp.setString(prefKeyModel, _model);
      needsRestart = true;
    }

    if (systemInstructions != null &&
        systemInstructions != _systemInstructions) {
      _systemInstructions = systemInstructions;
      await sp.setString(prefKeyInstructions, _systemInstructions);
      needsRestart = true;
    }

    notifyListeners();

    if (needsRestart) {
      await restartAgent();
    }
  }

  /// Starts or restarts the [Agent] session.
  Future<bool> restartAgent() async {
    _isInitializing = true;
    _lastError = null;
    notifyListeners();

    addLog(
      'Restarting agent session (model: $_model)...',
      direction: LogDirection.system,
    );

    try {
      if (_agent != null) {
        try {
          await _agent!.stop();
          addLog('Previous agent stopped.', direction: LogDirection.system);
        } catch (e) {
          addLog('Error stopping agent: $e', direction: LogDirection.error);
        }
        _agent = null;
      }

      final config = LocalAgentConfig(
        apiKey: apiKey,
        model: _model,
        systemInstructions: _systemInstructions,
        policies: [allowAll()],
        debugConfig: DebugConfig(
          level: Level.ALL,
          enableServerSideTracing: true,
        ),
      );

      final agent = Agent(config);
      await agent.start();
      _agent = agent;
      _isInitializing = false;
      addLog(
        'Agent started successfully with model $_model.',
        direction: LogDirection.system,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _isInitializing = false;
      _lastError = e.toString();
      _agent = null;
      addLog('Failed to start agent: $e', direction: LogDirection.error);
      notifyListeners();
      return false;
    }
  }

  /// Cancels any currently active response streaming.
  Future<void> cancelGeneration() async {
    if (_activeResponse != null || _isGenerating) {
      try {
        _activeResponse?.cancel();
        addLog(
          '>>> User requested cancellation of active response.',
          direction: LogDirection.outbound,
        );
      } catch (e) {
        addLog('Error cancelling response: $e', direction: LogDirection.error);
      }

      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.completeError(
          AntigravityCancelledException('Generation was cancelled.'),
        );
        _generationCompleter = null;
      }

      _activeResponse = null;
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Clears the session and starts a clean conversation.
  Future<void> clearSession() async {
    addLog('Clearing conversation session.', direction: LogDirection.system);
    await cancelGeneration();
    await restartAgent();
  }

  /// Sends a user message to the agent and streams back thoughts and text chunks.
  Future<void> sendMessage({
    required String prompt,
    required void Function(String token) onToken,
    required void Function(String thought) onThought,
    required void Function(String error) onError,
    required VoidCallback onDone,
  }) async {
    if (_isGenerating) return;

    if (_agent == null) {
      final success = await restartAgent();
      if (!success) {
        onError(_lastError ?? 'Failed to initialize Antigravity agent.');
        onDone();
        return;
      }
    }

    _isGenerating = true;
    addLog(
      '>>> Sending prompt to Antigravity: "$prompt"',
      direction: LogDirection.outbound,
    );
    notifyListeners();

    StreamSubscription<String>? thoughtSub;
    StreamSubscription<String>? textSub;

    try {
      final response = await _agent!.chat(prompt);
      _activeResponse = response;

      final completer = Completer<void>();
      _generationCompleter = completer;

      // Stream thoughts/reasoning in parallel
      thoughtSub = response.thoughts.listen(
        (thoughtChunk) {
          onThought(thoughtChunk);
        },
        onError: (err) {
          addLog('Thought stream error: $err', direction: LogDirection.error);
        },
      );

      // Stream text tokens
      textSub = response.textStream.listen(
        (token) {
          onToken(token);
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future;
      addLog(
        '<<< Response generation complete.',
        direction: LogDirection.inbound,
      );
    } catch (e) {
      if (e is AntigravityCancelledException) {
        addLog('Generation was cancelled.', direction: LogDirection.system);
      } else {
        addLog('Chat error: $e', direction: LogDirection.error);
        onError(e.toString());
      }
    } finally {
      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.complete();
      }
      _generationCompleter = null;
      await thoughtSub?.cancel();
      await textSub?.cancel();
      _activeResponse = null;
      _isGenerating = false;
      notifyListeners();
      onDone();
    }
  }

  @override
  void dispose() {
    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.completeError(
        AntigravityCancelledException('Service disposed.'),
      );
      _generationCompleter = null;
    }
    _logSubscription?.cancel();
    _activeResponse?.cancel();
    _agent?.stop();
    _logNotifier.dispose();
    super.dispose();
  }
}
