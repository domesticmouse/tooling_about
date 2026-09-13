import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/antigravity_service.dart';
import 'ui/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AntigravityChatApp(prefs: prefs));
}

/// Root widget for the Antigravity Chat Application.
class AntigravityChatApp extends StatefulWidget {
  final SharedPreferences? prefs;

  const AntigravityChatApp({super.key, this.prefs});

  @override
  State<AntigravityChatApp> createState() => _AntigravityChatAppState();
}

class _AntigravityChatAppState extends State<AntigravityChatApp> {
  late final AntigravityService _service;

  @override
  void initState() {
    super.initState();
    _service = AntigravityService(prefs: widget.prefs);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Chat',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: ChatScreen(service: _service),
    );
  }
}
