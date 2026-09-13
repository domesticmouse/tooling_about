import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/models/process_log_entry.dart';
import 'package:tooling_about/services/antigravity_service.dart';
import 'package:tooling_about/ui/process_log_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AntigravityService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = AntigravityService(prefs: prefs);
    service.clearLogs();
  });

  Widget buildPanelApp({VoidCallback? onClose}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: ProcessLogPanel(service: service, onClose: onClose),
        ),
      ),
    );
  }

  group('ProcessLogPanel Interactions', () {
    testWidgets('shows empty placeholder when log queue is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      expect(find.text('No subprocess messages'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('filter chips filter messages by direction', (tester) async {
      service.addLogEntry(
        ProcessLogEntry(
          id: '1',
          timestamp: DateTime.now(),
          message: '<<< Inbound message payload: {"id": 1}',
          direction: LogDirection.inbound,
        ),
      );
      service.addLogEntry(
        ProcessLogEntry(
          id: '2',
          timestamp: DateTime.now(),
          message: '>>> Outbound tool query: {"tool": "search"}',
          direction: LogDirection.outbound,
        ),
      );
      service.addLogEntry(
        ProcessLogEntry(
          id: '3',
          timestamp: DateTime.now(),
          message: 'System initialization message',
          direction: LogDirection.system,
        ),
      );
      service.addLogEntry(
        ProcessLogEntry(
          id: '4',
          timestamp: DateTime.now(),
          message: 'Critical error encountered',
          direction: LogDirection.error,
        ),
      );

      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      // All 4 should be present under 'All' filter
      expect(find.text('IN <<<'), findsOneWidget);
      expect(find.text('OUT >>>'), findsOneWidget);
      expect(find.text('SYS'), findsOneWidget);
      expect(find.text('ERR'), findsOneWidget);

      // Tap 'In (<<<)'
      await tester.tap(find.text('In (<<<)'));
      await tester.pumpAndSettle();
      expect(find.text('IN <<<'), findsOneWidget);
      expect(find.text('OUT >>>'), findsNothing);
      expect(find.text('SYS'), findsNothing);
      expect(find.text('ERR'), findsNothing);

      // Tap 'Out (>>>)'
      await tester.tap(find.text('Out (>>>)'));
      await tester.pumpAndSettle();
      expect(find.text('IN <<<'), findsNothing);
      expect(find.text('OUT >>>'), findsOneWidget);
      expect(find.text('SYS'), findsNothing);
      expect(find.text('ERR'), findsNothing);

      // Tap 'Errors'
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();
      expect(find.text('IN <<<'), findsNothing);
      expect(find.text('OUT >>>'), findsNothing);
      expect(find.text('SYS'), findsNothing);
      expect(find.text('ERR'), findsOneWidget);

      // Return to 'All'
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('IN <<<'), findsOneWidget);
      expect(find.text('OUT >>>'), findsOneWidget);
      expect(find.text('SYS'), findsOneWidget);
      expect(find.text('ERR'), findsOneWidget);
    });

    testWidgets('search bar filters log entries by text content', (
      tester,
    ) async {
      service.addLogEntry(
        ProcessLogEntry(
          id: '1',
          timestamp: DateTime.now(),
          message: 'Connecting to host 127.0.0.1',
          direction: LogDirection.system,
        ),
      );
      service.addLogEntry(
        ProcessLogEntry(
          id: '2',
          timestamp: DateTime.now(),
          message: 'Received token stream',
          direction: LogDirection.inbound,
        ),
      );

      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      expect(find.text('Connecting to host 127.0.0.1'), findsOneWidget);
      expect(find.text('Received token stream'), findsOneWidget);

      // Enter search term
      await tester.enterText(find.byType(TextField), 'token');
      await tester.pumpAndSettle();

      expect(find.text('Connecting to host 127.0.0.1'), findsNothing);
      expect(find.text('Received token stream'), findsOneWidget);

      // Search with non-matching query
      await tester.enterText(find.byType(TextField), 'non-existent-keyword');
      await tester.pumpAndSettle();

      expect(find.text('No subprocess messages'), findsOneWidget);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Connecting to host 127.0.0.1'), findsOneWidget);
      expect(find.text('Received token stream'), findsOneWidget);
    });

    testWidgets('clear logs button empties logs and updates UI', (
      tester,
    ) async {
      service.addLogEntry(
        ProcessLogEntry(
          id: '1',
          timestamp: DateTime.now(),
          message: 'Test log entry',
          direction: LogDirection.system,
        ),
      );

      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      expect(find.text('Test log entry'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);

      // Tap clear trace button
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      expect(service.processLogs, isEmpty);
      expect(find.text('No subprocess messages'), findsOneWidget);
    });

    testWidgets('toggle auto-scroll changes icon and state', (tester) async {
      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      // Initial state is auto-scroll enabled (Icons.arrow_downward)
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // Tap to toggle off
      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Tap to toggle back on
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('copy button copies payload and displays SnackBar', (
      tester,
    ) async {
      service.addLogEntry(
        ProcessLogEntry(
          id: '1',
          timestamp: DateTime.now(),
          message: '<<< response: {"hello": "world"}',
          direction: LogDirection.inbound,
        ),
      );

      await tester.pumpWidget(buildPanelApp());
      await tester.pumpAndSettle();

      expect(find.text('YAML'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(find.text('YAML payload copied to clipboard'), findsOneWidget);
    });

    testWidgets('onClose callback triggers when close button is tapped', (
      tester,
    ) async {
      bool closed = false;

      await tester.pumpWidget(buildPanelApp(onClose: () => closed = true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
