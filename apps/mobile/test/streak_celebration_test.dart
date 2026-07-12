import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/streaks/streak_celebration.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

import 'support/fake_sfx.dart';

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

Widget _host(QuizResult result, {FakeSfxService? sfx}) => ProviderScope(
      overrides: [overrideSfxWith(sfx ?? FakeSfxService())],
      child: MaterialApp(
        // Force reduced motion above the Navigator so the modal route inherits
        // it and the art (confetti/flame/owl) render static placeholders.
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

    testWidgets('passing fires the fanfare then the streak cue',
        (tester) async {
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(_result(passed: true), sfx: sfx));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // fanfare on open, streak after the ~450ms timer, tap on dismiss.
      expect(sfx.played, contains(SoundEffect.fanfare));
      expect(sfx.played, contains(SoundEffect.streak));
    });

    testWidgets('failing stays quiet (no fanfare/streak)', (tester) async {
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(_result(passed: false), sfx: sfx));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(sfx.played, isNot(contains(SoundEffect.fanfare)));
      expect(sfx.played, isNot(contains(SoundEffect.streak)));
    });
  });
}
