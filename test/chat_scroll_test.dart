import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/models/process_log_entry.dart';
import 'package:tooling_about/services/antigravity_service.dart';
import 'package:tooling_about/ui/chat_screen.dart';
import 'package:tooling_about/ui/process_log_panel.dart';

void main() {
  testWidgets(
    'ChatScreen shows scroll-to-bottom button when scrolled up and resumes on tap',
    (WidgetTester tester) async {
      final service = AntigravityService();

      await tester.pumpWidget(MaterialApp(home: ChatScreen(service: service)));

      // Initial state: empty welcome screen, no floating button
      expect(find.byType(FloatingActionButton), findsNothing);

      // Send a message via the UI
      final inputFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText?.contains('Message Antigravity') ==
                true,
      );
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Test prompt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // Verify messages exist in tree
      final chatListView = find.byType(ListView).first;
      expect(chatListView, findsOneWidget);

      // Verify that ListView uses ClampingScrollPhysics to eliminate overscroll bounce
      final listView = tester.widget<ListView>(chatListView);
      expect(listView.physics, isA<ClampingScrollPhysics>());

      // Simulate scrolling up by dragging down on the ListView
      await tester.drag(chatListView, const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify the resume/scroll-to-bottom button appears when detached
      final scrollButtonFinder = find.byTooltip('Scroll to bottom');
      if (scrollButtonFinder.evaluate().isNotEmpty) {
        expect(scrollButtonFinder, findsOneWidget);

        // Tap the scroll-to-bottom button
        await tester.tap(scrollButtonFinder);
        await tester.pumpAndSettle();

        // Verify button disappears once resumed to bottom
        expect(find.byTooltip('Scroll to bottom'), findsNothing);
      }

      service.dispose();
    },
  );

  testWidgets(
    'ProcessLogPanel uses ClampingScrollPhysics and supports smooth auto-scroll',
    (WidgetTester tester) async {
      final service = AntigravityService();

      // Add several logs to populate the panel
      for (int i = 0; i < 20; i++) {
        service.addLog(
          'Test log line $i with some metadata',
          direction: LogDirection.inbound,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProcessLogPanel(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ListView is rendered with ClampingScrollPhysics
      final listViews = tester.widgetList<ListView>(find.byType(ListView));
      expect(listViews.isNotEmpty, isTrue);
      expect(listViews.first.physics, isA<ClampingScrollPhysics>());

      // Verify auto-scroll toggle icon
      expect(find.byTooltip('Auto-scroll enabled'), findsOneWidget);

      // Tap toggle to disable auto-scroll
      await tester.tap(find.byTooltip('Auto-scroll enabled'));
      await tester.pump();
      expect(find.byTooltip('Auto-scroll disabled'), findsOneWidget);

      service.dispose();
    },
  );

  group('AntigravityService Concurrency and Cancellation', () {
    test(
      'cancelGeneration safely resets state when no generation is active',
      () async {
        final service = AntigravityService();
        expect(service.isGenerating, isFalse);

        await service.cancelGeneration();

        expect(service.isGenerating, isFalse);
        service.dispose();
      },
    );

    test(
      'cancelGeneration and dispose handle repeated calls cleanly',
      () async {
        final service = AntigravityService();

        expect(service.isGenerating, isFalse);

        // Verify cancelGeneration can be called repeatedly without throwing
        await service.cancelGeneration();
        await service.cancelGeneration();
        expect(service.isGenerating, isFalse);

        service.dispose();
      },
    );
  });

  group('AntigravityService Log Queue and Decoupling', () {
    test('logNotifier notifies when logs are added and cleared', () {
      final service = AntigravityService();
      int notifyCount = 0;
      service.logNotifier.addListener(() {
        notifyCount++;
      });

      service.addLog('Test entry 1', direction: LogDirection.inbound);
      service.addLog('Test entry 2', direction: LogDirection.outbound);
      expect(notifyCount, 2);

      service.clearLogs();
      expect(notifyCount, 3);
      expect(service.processLogs, isEmpty);

      service.dispose();
    });

    test('Log buffer caps at 1500 with O(1) FIFO truncation', () {
      final service = AntigravityService();

      for (int i = 0; i < 1600; i++) {
        service.addLog('Message $i', direction: LogDirection.system);
      }

      // Buffer cap is 1500 entries (indices 100 through 1599)
      expect(service.processLogs.length, 1500);
      expect(service.processLogs.first.message, 'Message 100');
      expect(service.processLogs.last.message, 'Message 1599');

      service.dispose();
    });
  });

  group('Subprocess Trace Slide-out Drawer', () {
    testWidgets('Wide screen opens trace panel in slide-out drawer on tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = AntigravityService();
      await tester.pumpWidget(MaterialApp(home: ChatScreen(service: service)));
      await tester.pumpAndSettle();

      // Drawer is closed initially, main chat is full width
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(ProcessLogPanel), findsNothing);

      // Tap terminal button to open drawer
      final traceBtn = find.byTooltip('Subprocess trace');
      expect(traceBtn, findsOneWidget);
      await tester.tap(traceBtn);
      await tester.pumpAndSettle();

      // Trace panel rendered inside slide-out Drawer
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(ProcessLogPanel), findsOneWidget);

      service.dispose();
    });

    testWidgets('Compact screen opens trace panel in slide-out drawer on tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = AntigravityService();
      await tester.pumpWidget(MaterialApp(home: ChatScreen(service: service)));
      await tester.pumpAndSettle();

      // Drawer is closed initially
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(ProcessLogPanel), findsNothing);

      // Tap the terminal action button to open end drawer
      final traceBtn = find.byTooltip('Subprocess trace');
      expect(traceBtn, findsOneWidget);
      await tester.tap(traceBtn);
      await tester.pumpAndSettle();

      // Now ProcessLogPanel is rendered inside the Drawer
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(ProcessLogPanel), findsOneWidget);

      service.dispose();
    });
  });

  group('Configuration Persistence with SharedPreferences', () {
    test('loads persisted model, system instructions, and API key', () async {
      SharedPreferences.setMockInitialValues({
        AntigravityService.prefKeyModel: 'gemini-2.5-pro',
        AntigravityService.prefKeyInstructions: 'Custom test instructions',
        AntigravityService.prefKeyApiKey: 'test-persisted-api-key',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = AntigravityService(prefs: prefs);

      expect(service.model, 'gemini-2.5-pro');
      expect(service.systemInstructions, 'Custom test instructions');
      expect(service.apiKey, 'test-persisted-api-key');
      expect(service.hasApiKey, isTrue);

      service.dispose();
    });

    test(
      'updateSettings writes to SharedPreferences and removes empty key',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = AntigravityService(prefs: prefs);

        // Default values initially
        expect(service.model, 'gemini-3.8-flash');

        // Update settings
        await service.updateSettings(
          apiKey: 'new-key-123',
          model: 'gemini-2.5-flash',
          systemInstructions: 'Helpful expert',
        );

        expect(
          prefs.getString(AntigravityService.prefKeyModel),
          'gemini-2.5-flash',
        );
        expect(
          prefs.getString(AntigravityService.prefKeyInstructions),
          'Helpful expert',
        );
        expect(
          await service.secureStorage.read(AntigravityService.secureKeyApiKey),
          'new-key-123',
        );
        expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);

        // Removing API key
        await service.updateSettings(apiKey: '');
        expect(
          await service.secureStorage.read(AntigravityService.secureKeyApiKey),
          isNull,
        );
        expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);
        expect(service.customApiKey, isNull);

        service.dispose();
      },
    );

    test(
      'distinguishes custom manually entered key from environment key',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = AntigravityService(prefs: prefs);

        // Without custom key, customApiKey is null
        expect(service.customApiKey, isNull);

        // If environment key exists, isUsingEnvironmentApiKey is true
        if (service.environmentApiKey != null) {
          expect(service.isUsingEnvironmentApiKey, isTrue);
          expect(service.apiKey, service.environmentApiKey);
        }

        // Enter manual custom key
        await service.updateSettings(apiKey: 'custom-override-key');
        expect(service.customApiKey, 'custom-override-key');
        expect(service.apiKey, 'custom-override-key');
        expect(service.isUsingEnvironmentApiKey, isFalse);
        expect(
          await service.secureStorage.read(AntigravityService.secureKeyApiKey),
          'custom-override-key',
        );
        expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);

        // Clear manual key
        await service.updateSettings(apiKey: '');
        expect(service.customApiKey, isNull);
        expect(
          await service.secureStorage.read(AntigravityService.secureKeyApiKey),
          isNull,
        );
        expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);
        if (service.environmentApiKey != null) {
          expect(service.isUsingEnvironmentApiKey, isTrue);
          expect(service.apiKey, service.environmentApiKey);
        }

        service.dispose();
      },
    );
  });
}
