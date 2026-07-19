import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host() => const ProviderScope(
      child: MaterialApp(home: SettingsPage()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsPage', () {
    testWidgets('shows the sound toggle and a friendly recap-voice label',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      expect(find.text('Sound effects'), findsOneWidget);
      // The two polished toggle rows: sound effects + the nightly reminder.
      expect(find.text('Nightly reminder'), findsOneWidget);
      expect(find.text('Recap voice'), findsOneWidget);
      // Friendly label, not the raw model id.
      expect(find.text('Thalia — English (US)'), findsOneWidget);
      expect(find.text('aura-2-thalia-en'), findsNothing);
    });

    testWidgets(
        'replaces the dead Notifications row with a real nightly-reminder '
        'toggle (nothing dead-ends)', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // No "Notifications" chevron row any more.
      expect(find.text('Notifications'), findsNothing);
      // A real, functional reminder row instead of the old "coming soon".
      expect(find.text('Nightly reminder'), findsOneWidget);
      expect(find.text('Coming soon'), findsNothing);
    });

    testWidgets('groups admin/debug under a Developer section', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      // enableAdminDebug defaults to true in debug/test builds. The section
      // label is rendered in the prototype's tracked uppercase style.
      expect(find.text('DEVELOPER'), findsOneWidget);
      expect(find.text('Admin / debug'), findsOneWidget);
    });
  });
}
