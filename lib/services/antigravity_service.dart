import 'dart:async';
import 'dart:io';

import 'package:antigravity/antigravity.dart';
import 'package:flutter/foundation.dart';

/// Service managing the lifecycle of the Google Antigravity [Agent].
class AntigravityService extends ChangeNotifier {
  Agent? _agent;
  ChatResponse? _activeResponse;

  String _model = 'gemini-3.8-flash';
  String? _apiKey;
  String _systemInstructions =
      'You are a helpful, insightful AI assistant running in a desktop Flutter app powered by Google Antigravity.';

  bool _isInitializing = false;
  bool _isGenerating = false;
  String? _lastError;

  AntigravityService() {
    // Attempt to load API key from environment variable if available.
    try {
      final envKey = Platform.environment['GEMINI_API_KEY'];
      if (envKey != null && envKey.isNotEmpty) {
        _apiKey = envKey;
      }
    } catch (_) {}
  }

  String get model => _model;
  String? get apiKey => _apiKey;
  String get systemInstructions => _systemInstructions;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;
  bool get isReady => _agent != null && !_isInitializing;
  String? get lastError => _lastError;

  bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  /// Updates settings and recreates the agent session if needed.
  Future<void> updateSettings({
    String? apiKey,
    String? model,
    String? systemInstructions,
  }) async {
    bool needsRestart = false;

    if (apiKey != null && apiKey != _apiKey) {
      _apiKey = apiKey.trim().isEmpty ? null : apiKey.trim();
      needsRestart = true;
    }

    if (model != null && model != _model) {
      _model = model;
      needsRestart = true;
    }

    if (systemInstructions != null &&
        systemInstructions != _systemInstructions) {
      _systemInstructions = systemInstructions;
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

    try {
      if (_agent != null) {
        try {
          await _agent!.stop();
        } catch (e) {
          debugPrint('Error stopping previous agent: $e');
        }
        _agent = null;
      }

      final config = LocalAgentConfig(
        apiKey: _apiKey,
        model: _model,
        systemInstructions: _systemInstructions,
        policies: [allowAll()],
      );

      final agent = Agent(config);
      await agent.start();
      _agent = agent;
      _isInitializing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isInitializing = false;
      _lastError = e.toString();
      _agent = null;
      notifyListeners();
      return false;
    }
  }

  /// Cancels any currently active response streaming.
  Future<void> cancelGeneration() async {
    if (_activeResponse != null) {
      try {
        _activeResponse!.cancel();
      } catch (e) {
        debugPrint('Error cancelling response: $e');
      }
      _activeResponse = null;
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Clears the session and starts a clean conversation.
  Future<void> clearSession() async {
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
    notifyListeners();

    StreamSubscription<String>? thoughtSub;
    StreamSubscription<String>? textSub;

    try {
      final response = await _agent!.chat(prompt);
      _activeResponse = response;

      final completer = Completer<void>();

      // Stream thoughts/reasoning in parallel
      thoughtSub = response.thoughts.listen(
        (thoughtChunk) {
          onThought(thoughtChunk);
        },
        onError: (err) {
          debugPrint('Thought stream error: $err');
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
    } catch (e) {
      if (e is AntigravityCancelledException) {
        // Generation was cancelled gracefully by user
      } else {
        onError(e.toString());
      }
    } finally {
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
    _activeResponse?.cancel();
    _agent?.stop();
    super.dispose();
  }
}
