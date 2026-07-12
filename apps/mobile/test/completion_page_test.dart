import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owlnighter/features/quiz/completion_page.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

import 'support/fake_sfx.dart';

/// The completion sequence is the payoff beat. This drives the real page and
/// asserts it renders the streak/XP/accuracy payoff and that CONTINUE navigates
/// back to the reading path (a placeholder route stands in for the path map).
QuizResult _result({required bool passed}) => QuizResult(
      quizId: 'qi1',
      correctCount: passed ? 4 : 1,
      totalCount: 4,
      passed: passed,
      markedComplete: passed,
      perQuestion: const [],
      streak: const StreakState(
        currentStreak: 7,
        longestStreak: 9,
        xpGained: 20,
      ),
    );

Widget _host(QuizResult result, {FakeSfxService? sfx}) {
  final router = GoRouter(
    initialLocation: '/plan/p1/complete',
    routes: [
      GoRoute(
        path: '/plan/:planId',
        builder: (_, __) => const Scaffold(body: Text('PATH MAP')),
        routes: [
          GoRoute(
            path: 'complete',
            builder: (_, state) => CompletionPage(
              planId: state.pathParameters['planId']!,
              result: result,
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [overrideSfxWith(sfx ?? FakeSfxService())],
    child: MaterialApp.router(
      routerConfig: router,
      // Force reduced motion so NightSky/confetti/flame render static and
      // pumpAndSettle can complete.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

void main() {
  group('CompletionPage', () {
    testWidgets('passing renders the payoff (title, XP, accuracy, streak)',
        (tester) async {
      await tester.pumpWidget(_host(_result(passed: true)));
      await tester.pumpAndSettle();

      expect(find.text('Night complete!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget); // accuracy 4/4
      expect(find.text('7'), findsOneWidget); // streak
      // XpCounter lands on +20 XP; the stat card shows +20 too.
      expect(find.textContaining('+20'), findsWidgets);
      expect(find.text('Continue'.toUpperCase()), findsOneWidget);
    });

    testWidgets('failing shows the gentle copy', (tester) async {
      await tester.pumpWidget(_host(_result(passed: false)));
      await tester.pumpAndSettle();
      expect(find.text('Good effort'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget); // 1/4
    });

    testWidgets('CONTINUE navigates back to the reading path', (tester) async {
      await tester.pumpWidget(_host(_result(passed: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('PATH MAP'), findsOneWidget);
    });

    testWidgets('passing fires the fanfare then the streak cue',
        (tester) async {
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(_result(passed: true), sfx: sfx));
      await tester.pumpAndSettle();

      expect(sfx.played, contains(SoundEffect.fanfare));
      expect(sfx.played, contains(SoundEffect.streak));
    });
  });
}
