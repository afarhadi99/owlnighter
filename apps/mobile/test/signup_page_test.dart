import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owlnighter/features/auth/signup_page.dart';
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
    initialLocation: '/signup',
    routes: [
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const Scaffold(body: Text('AUTH PAGE')),
      ),
      GoRoute(
        path: '/library',
        builder: (_, __) => const Scaffold(body: Text('LIBRARY')),
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
      // Reduced motion makes RewardButton call onTap synchronously instead of
      // after its ~200ms press animation — keeps these tests deterministic.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

/// The page scrolls on the small test viewport; bring a finder into view
/// before tapping it so the hit test lands on-screen.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

ApiException _invalidCode() => ApiException(
      statusCode: 400,
      code: 'invalid_referral_code',
      message: 'That code has already been used up.',
    );

void main() {
  group('SignupPage', () {
    testWidgets('shows email, password, referral code, and the submit CTA',
        (tester) async {
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: FakeReferralApi()),
      );
      await tester.pump();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Referral code'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('live-checks the referral code when the field loses focus',
        (tester) async {
      final referral = FakeReferralApi(
        validateResult: (valid: false, reason: 'Code expired.'),
      );
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: referral),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'DEAD-CODE',
      );
      // Move focus to another field to blur the code field and trigger the
      // check.
      await tester.tap(find.widgetWithText(TextField, 'Email'));
      await tester.pumpAndSettle();

      expect(referral.validateCalls, 1);
      expect(find.text('Code expired.'), findsOneWidget);
    });

    testWidgets('submit is disabled while signing up (no double submit)',
        (tester) async {
      // signUp never resolves, so the UI stays pinned in the loading state —
      // otherwise the fake future can resolve before we get to assert on it.
      final auth = FakeAuthRepository(hangSignUp: true);
      await tester.pumpWidget(
        _host(auth: auth, referral: FakeReferralApi()),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'GOOD1',
      );

      await _tap(tester, find.text('Create account'));
      await tester.pump(); // enters loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tapping again while loading must not fire a second signUp call.
      await tester.tap(
        find.byType(CircularProgressIndicator),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(auth.signUpCalls, 1);
    });

    testWidgets(
        'a signUp failure shows the error and never attempts activation',
        (tester) async {
      final auth = FakeAuthRepository(signUpError: StateError('boom'));
      final referral = FakeReferralApi();
      await tester.pumpWidget(_host(auth: auth, referral: referral));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'GOOD1',
      );
      await _tap(tester, find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
      expect(referral.activateCalls, 0);
      // Still in "Create account" mode — signup never succeeded, so a retry
      // must redo signUp, not just activation.
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets(
        'signUp succeeds, activation fails, then a same-screen retry succeeds '
        'and navigates to the library', (tester) async {
      final auth = FakeAuthRepository();
      final referral = FakeReferralApi(activateError: _invalidCode());
      await tester.pumpWidget(_host(auth: auth, referral: referral));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'DEAD1',
      );
      await _tap(tester, find.text('Create account'));
      await tester.pumpAndSettle();

      expect(auth.signUpCalls, 1);
      expect(referral.activateCalls, 1);
      expect(find.textContaining('already been used up'), findsOneWidget);
      // Button relabels to Activate: a retry only redoes activation.
      expect(find.text('Activate'), findsOneWidget);

      // Fix the code and retry — signUp must not run again.
      referral.activateError = null;
      await tester.enterText(
        find.widgetWithText(TextField, 'Referral code'),
        'GOOD1',
      );
      await _tap(tester, find.text('Activate'));
      await tester.pumpAndSettle();

      expect(auth.signUpCalls, 1); // unchanged
      expect(referral.activateCalls, 2);
      expect(referral.lastActivatedCode, 'GOOD1');
      expect(find.text('LIBRARY'), findsOneWidget);
    });

    testWidgets('the "already have an account" link goes to /auth',
        (tester) async {
      await tester.pumpWidget(
        _host(auth: FakeAuthRepository(), referral: FakeReferralApi()),
      );
      await tester.pump();

      await _tap(tester, find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('AUTH PAGE'), findsOneWidget);
    });
  });
}
