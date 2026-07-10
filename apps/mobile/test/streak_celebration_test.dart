import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/streaks/streak_celebration.dart';

/// The celebration is the payoff beat of the core loop. This drives the real
/// `showStreakCelebration` bottom sheet and asserts the streak + XP payoff
/// renders (StreakFlame degrades to its static placeholder under the test's
/// default reduced-motion, so no Rive asset is required).
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

Widget _host(QuizResult result) => MaterialApp(
      // Force reduced motion above the Navigator so the modal route inherits it
      // and StreakFlame renders its static placeholder (no Rive asset needed).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showStreakCelebration(context, result: result),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  group('streak celebration', () {
    testWidgets('passing shows the streak count, XP, and score',
        (tester) async {
      await tester.pumpWidget(_host(_result(passed: true)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Nice reading tonight!'), findsOneWidget);
      expect(find.text('4/4 correct'), findsOneWidget);
      expect(find.text('7'), findsOneWidget); // day streak
      expect(find.text('+20'), findsOneWidget); // XP
      expect(find.text('day streak'), findsOneWidget);
    });

    testWidgets('failing shows the gentle "Good effort" copy', (tester) async {
      await tester.pumpWidget(_host(_result(passed: false)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Good effort'), findsOneWidget);
      expect(find.text('1/4 correct'), findsOneWidget);
    });

    testWidgets('Done dismisses the sheet', (tester) async {
      await tester.pumpWidget(_host(_result(passed: true)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });
}
