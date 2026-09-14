import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooling_about/services/antigravity_service.dart';
import 'package:tooling_about/services/secure_key_store.dart';
import 'package:tooling_about/ui/settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createSettingsApp({required AntigravityService service}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => SettingsDialog.show(context, service),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
    );
  }

  group('SettingsDialog', () {
    testWidgets('shows environment API key badge when using env key', (
      tester,
    ) async {
      final service = AntigravityService(
        prefs: prefs,
        environmentApiKey: 'env-gemini-key-12345',
      );

      await tester.pumpWidget(createSettingsApp(service: service));
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Antigravity Settings'), findsOneWidget);
      expect(
        find.text('Using GEMINI_API_KEY from environment'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.eco), findsOneWidget);

      // Verify that the custom API key text field is empty (env key is not displayed)
      final apiKeyField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Environment key active') ==
                  true,
        ),
      );
      expect(apiKeyField.controller?.text, '');
    });

    testWidgets(
      'shows custom key stored badge and populates field when manual key exists',
      (tester) async {
        final service = AntigravityService(
          prefs: prefs,
          environmentApiKey: 'env-key',
        );
        service.updateSettings(apiKey: 'custom-secret-key');

        await tester.pumpWidget(createSettingsApp(service: service));
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Custom key stored'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);

        final apiKeyFinder = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.helperText?.contains(
                    'revert to environment variable',
                  ) ==
                  true,
        );
        expect(apiKeyFinder, findsOneWidget);
        final apiKeyField = tester.widget<TextField>(apiKeyFinder);
        expect(apiKeyField.controller?.text, 'custom-secret-key');
      },
    );

    testWidgets('toggles API key obscure text visibility on button tap', (
      tester,
    ) async {
      final service = AntigravityService(prefs: prefs);

      await tester.pumpWidget(createSettingsApp(service: service));
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Initially obscureText is true and icon is Icons.visibility
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      TextField field = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.suffixIcon != null,
        ),
      );
      expect(field.obscureText, isTrue);

      // Tap visibility button to toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      field = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.suffixIcon != null,
        ),
      );
      expect(field.obscureText, isFalse);

      // Tap again to re-obscure
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('cancels without saving changes', (tester) async {
      final service = AntigravityService(prefs: prefs);
      final initialModel = service.model;
      final initialInstructions = service.systemInstructions;

      await tester.pumpWidget(createSettingsApp(service: service));
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Enter new instructions
      final instructionsFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText?.contains('Enter persona') == true,
      );
      await tester.enterText(instructionsFinder, 'New Unsaved Persona');

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Antigravity Settings'), findsNothing);
      expect(service.systemInstructions, initialInstructions);
      expect(service.model, initialModel);
    });

    testWidgets(
      'saves and applies updated model, instructions, and custom API key',
      (tester) async {
        final service = AntigravityService(prefs: prefs);

        await tester.pumpWidget(createSettingsApp(service: service));
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        // Change model dropdown
        await tester.tap(find.text(service.model));
        await tester.pumpAndSettle();
        await tester.tap(find.text('gemini-2.5-pro').last);
        await tester.pumpAndSettle();

        // Enter API key
        final apiKeyFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.suffixIcon != null,
        );
        await tester.enterText(apiKeyFinder, 'new-saved-api-key');

        // Enter system instructions
        final instructionsFinder = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Enter persona') == true,
        );
        await tester.enterText(
          instructionsFinder,
          'You are an advanced Flutter architect.',
        );

        // Tap Save & Apply
        await tester.tap(find.text('Save & Apply'));
        await tester.pumpAndSettle();

        expect(find.text('Antigravity Settings'), findsNothing);
        expect(service.model, 'gemini-2.5-pro');
        expect(service.customApiKey, 'new-saved-api-key');
        expect(
          service.systemInstructions,
          'You are an advanced Flutter architect.',
        );
        expect(
          prefs.getString(AntigravityService.prefKeyModel),
          'gemini-2.5-pro',
        );
        expect(
          await service.secureStorage.read(AntigravityService.secureKeyApiKey),
          'new-saved-api-key',
        );
        expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);
        expect(
          prefs.getString(AntigravityService.prefKeyInstructions),
          'You are an advanced Flutter architect.',
        );
      },
    );

    testWidgets('clearing API key in dialog removes it from secure storage', (
      tester,
    ) async {
      final keyStore = InMemoryKeyStore({
        AntigravityService.secureKeyApiKey: 'existing-key',
      });
      final service = AntigravityService(prefs: prefs, secureStorage: keyStore);
      await service.secureStorageInitFuture;
      expect(service.customApiKey, 'existing-key');

      await tester.pumpWidget(createSettingsApp(service: service));
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      final apiKeyFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.suffixIcon != null,
      );
      await tester.enterText(apiKeyFinder, '');
      await tester.tap(find.text('Save & Apply'));
      await tester.pumpAndSettle();

      expect(service.customApiKey, isNull);
      expect(
        await service.secureStorage.read(AntigravityService.secureKeyApiKey),
        isNull,
      );
      expect(prefs.getString(AntigravityService.prefKeyApiKey), isNull);
    });
  });
}
