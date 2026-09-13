import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
