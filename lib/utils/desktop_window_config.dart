import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Configuration and initialization helper for desktop window dimensions and constraints.
class DesktopWindowConfig {
  /// The minimum allowable window dimensions (width: 800, height: 600).
  static const Size minimumSize = Size(800, 600);

  /// The standard initial launch window dimensions (width: 1100, height: 750).
  static const Size defaultSize = Size(1100, 750);

  /// Default window title for the desktop shell.
  static const String appTitle = 'Antigravity Chat';

  /// Initializes native desktop window properties when running on desktop platforms
  /// (macOS, Windows, Linux).
  ///
  /// Safe to call across all environments; automatically skips execution in test runners
  /// and non-desktop targets.
  static Future<void> initialize({
    WindowManager? wm,
    bool isTest = false,
  }) async {
    if (isTest || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final manager = wm ?? windowManager;
      await manager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: defaultSize,
        minimumSize: minimumSize,
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: appTitle,
      );

      await manager.waitUntilReadyToShow(windowOptions, () async {
        await manager.setMinimumSize(minimumSize);
        await manager.show();
        await manager.focus();
      });
    }
  }
}
