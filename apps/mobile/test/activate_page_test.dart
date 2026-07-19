import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owlnighter/features/auth/activate_page.dart';
import 'package:owlnighter/services/api/auth_repository_impl.dart';
import 'package:owlnighter/services/api/referral_api.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_referral_api.dart';
import 'support/fake_sfx.dart';

Widget _host({
  required FakeAuthRepository auth,
  required FakeReferralApi referral,
}) {
  final router = GoRouter(
    initialLocation: '/activate',
    routes: [
      GoRoute(
        path: '/activate',
        builder: (_, __) => const ActivatePage(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryInterfaceProvider.overrideWithValue(auth),
      referralApiProvider.overrideWithValue(referral),
      overrideSfxWith(FakeSfxService()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

/// The page can scroll on the small test viewport; bring a finder into view
/// before tapping so the hit test lands on-screen.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  group('ActivatePage', () {
    testWidgets('shows a blank referral-code field and the Activate CTA',
        (tester) async {
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: FakeReferralApi()),
      );
      await tester.pump();

      expect(find.text('Referral code'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
      // Blank by design: this is where a Google sign-in lands with no code
      // ever having been entered.
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Referral code'),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('submitting calls activateAccount with the entered code',
        (tester) async {
      final referral = FakeReferralApi();
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: referral),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'WELCOME1',
      );
      await _tap(tester, find.text('Activate'));
      await tester.pumpAndSettle();

      expect(referral.activateCalls, 1);
      expect(referral.lastActivatedCode, 'WELCOME1');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an activation error is shown and the field stays editable',
        (tester) async {
      final referral = FakeReferralApi(
        activateError: ApiException(
          statusCode: 400,
          code: 'referral_code_invalid',
          message: 'That code is no longer active.',
        ),
      );
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: referral),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'STALE1',
      );
      await _tap(tester, find.text('Activate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no longer active'), findsOneWidget);
      // Editable retry: the field is still there and enabled.
      expect(find.widgetWithText(TextField, 'Referral code'), findsOneWidget);
    });

    testWidgets('sign out calls the auth repository', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(_host(auth: auth, referral: FakeReferralApi()));
      await tester.pump();

      await _tap(tester, find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
    });
  });
}
