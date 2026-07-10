import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/auth/auth_page.dart';

/// AuthPage renders inside a ProviderScope (it reads authControllerProvider)
/// and a MaterialApp (Scaffold/TextField ancestry). No provider overrides are
/// needed: merely building the page touches neither secure storage nor the
/// network — those are only hit when a button is tapped.
Widget _host() => const ProviderScope(
      child: MaterialApp(home: AuthPage()),
    );

void main() {
  group('AuthPage', () {
    testWidgets('shows the real sign-in affordances', (tester) async {
      await tester.pumpWidget(_host());
      // The auth controller's async build starts in loading (the button shows a
      // spinner); pump once so it settles and the labels render.
      await tester.pump();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Email me a magic link'), findsOneWidget);
    });

    testWidgets('exposes the debug "Continue as dev" fast path',
        (tester) async {
      // `flutter test` runs in debug (kDebugMode == true), so the dev button is
      // present. This guards the dev auth entry point against regressions.
      await tester.pumpWidget(_host());
      await tester.pump();
      expect(find.text('Continue as dev'), findsOneWidget);
    });
  });
}
