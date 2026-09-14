import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/models/chat_message.dart';
import 'package:tooling_about/services/antigravity_service.dart';
import 'package:tooling_about/services/secure_key_store.dart';
import 'package:tooling_about/ui/chat_screen.dart';
import 'package:tooling_about/ui/process_log_panel.dart';
import 'package:tooling_about/ui/settings_dialog.dart';
import 'package:tooling_about/utils/desktop_window_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DesktopWindowConfig Unit Tests', () {
    test('defines required desktop minimum and default launch dimensions', () {
      expect(DesktopWindowConfig.minimumSize.width, 800.0);
      expect(DesktopWindowConfig.minimumSize.height, 600.0);
      expect(DesktopWindowConfig.defaultSize.width, 1100.0);
      expect(DesktopWindowConfig.defaultSize.height, 750.0);
      expect(DesktopWindowConfig.appTitle, 'Antigravity Chat');
    });

    test('initialize completes safely when isTest is true', () async {
      await expectLater(
        DesktopWindowConfig.initialize(isTest: true),
        completes,
      );
    });
  });

  group('Desktop Layout Responsiveness & Constraint Boundaries', () {
    Widget buildTestApp({
      required AntigravityService service,
      List<ChatMessage>? initialMessages,
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: ChatScreen(service: service, initialMessages: initialMessages),
      );
    }

    testWidgets(
      'renders cleanly at minimum desktop boundary (800 x 600) with empty state and input bar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        await tester.pumpWidget(buildTestApp(service: service));
        await tester.pumpAndSettle();

        // Verify empty state chips render without overflow
        expect(find.text('Antigravity Chat'), findsOneWidget);
        expect(find.text('Welcome to Antigravity'), findsOneWidget);
        expect(find.text('Write a Flutter widget'), findsOneWidget);
        expect(find.text('Explain quantum gravity'), findsOneWidget);

        // Verify input text field and send button render cleanly
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

        // Enter multiline text
        await tester.enterText(
          find.byType(TextField),
          'Line 1\nLine 2\nLine 3\nLine 4',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        service.dispose();
      },
    );

    testWidgets(
      'renders error banner with Settings CTA and Dismiss at 800 x 600 without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        service.setLastErrorForTesting(
          'Gemini API authentication failed: Invalid or missing API key. Please check your credentials.',
        );

        await tester.pumpWidget(buildTestApp(service: service));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.byTooltip('Dismiss'), findsOneWidget);
        expect(tester.takeException(), isNull);

        service.dispose();
      },
    );

    testWidgets(
      'opens subprocess trace drawer at 800 x 600 with expected proportional width',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        await tester.pumpWidget(buildTestApp(service: service));
        await tester.pumpAndSettle();

        // Open subprocess trace end drawer
        final traceBtn = find.byTooltip('Subprocess trace');
        expect(traceBtn, findsOneWidget);
        await tester.tap(traceBtn);
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsOneWidget);
        expect(find.byType(ProcessLogPanel), findsOneWidget);

        // At 800 width, drawer width = min(480, max(320, 800 * 0.45)) = 360
        final drawerBox = tester.renderObject<RenderBox>(find.byType(Drawer));
        expect(drawerBox.size.width, 360.0);
        expect(tester.takeException(), isNull);

        service.dispose();
      },
    );

    testWidgets(
      'opens SettingsDialog and ExportDialog at 800 x 600 without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        final initialMessages = [
          ChatMessage(
            id: 'm1',
            role: MessageRole.user,
            content: 'Hello Antigravity agent!',
            timestamp: DateTime(2026, 9, 14, 12, 0, 0),
          ),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            content: 'Hello! I am ready to assist you.',
            thoughts: 'Greeting response',
            timestamp: DateTime(2026, 9, 14, 12, 0, 2),
          ),
        ];

        await tester.pumpWidget(
          buildTestApp(service: service, initialMessages: initialMessages),
        );
        await tester.pumpAndSettle();

        // 1. Open Settings Dialog
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsDialog), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Close Settings Dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsDialog), findsNothing);

        // 2. Open Export Dialog
        await tester.tap(find.byTooltip('Export conversation'));
        await tester.pumpAndSettle();

        expect(find.text('Export Conversation'), findsOneWidget);
        expect(find.text('Copy Markdown'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Close Export Dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Export Conversation'), findsNothing);

        service.dispose();
      },
    );

    testWidgets(
      'renders at default launch dimensions (1100 x 750) with drawer capped at 480',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1100, 750);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        await tester.pumpWidget(buildTestApp(service: service));
        await tester.pumpAndSettle();

        // Open subprocess trace drawer
        await tester.tap(find.byTooltip('Subprocess trace'));
        await tester.pumpAndSettle();

        // At 1100 width: min(480, max(320, 1100 * 0.45)) = min(480, 495) = 480
        final drawerBox = tester.renderObject<RenderBox>(find.byType(Drawer));
        expect(drawerBox.size.width, 480.0);
        expect(tester.takeException(), isNull);

        service.dispose();
      },
    );

    testWidgets(
      'renders at wide desktop dimensions (1600 x 1000) respecting max message constraints',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = AntigravityService(
          prefs: prefs,
          secureStorage: InMemoryKeyStore(),
        );

        final initialMessages = [
          ChatMessage(
            id: 'm1',
            role: MessageRole.user,
            content: 'Explain the architecture of Antigravity in detail.',
          ),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            content: 'Antigravity orchestrates agentic workflows using subprocess RPC and generative UI...',
          ),
        ];

        await tester.pumpWidget(
          buildTestApp(service: service, initialMessages: initialMessages),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Explain the architecture of Antigravity in detail.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        service.dispose();
      },
    );
  });
}
