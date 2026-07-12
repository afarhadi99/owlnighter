import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owlnighter/features/nightly_session/nightly_session_controller.dart';
import 'package:owlnighter/features/quiz/quiz_page.dart';
import 'package:owlnighter/services/api/extras_api.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

import 'support/fake_api.dart';
import 'support/fake_sfx.dart';

/// Seeds the nightly session's generated-quiz provider with a fixed quiz so
/// QuizPage renders without a network round-trip.
class _SeededGen extends QuizGenController {
  _SeededGen(this.quiz);
  final QuizInstance quiz;
  @override
  Future<QuizInstance?> build() async => quiz;
}

QuizInstance _quiz() => const QuizInstance(
      quizId: 'qi1',
      stepId: 's1',
      quizMode: QuizMode.grounded,
      questions: [
        QuizQuestion(
          id: 'q1',
          kind: QuizQuestionKind.multipleChoice,
          prompt: 'Who narrates?',
          quizMode: QuizMode.grounded,
          options: ['Ishmael', 'Ahab'],
        ),
        QuizQuestion(
          id: 'q2',
          kind: QuizQuestionKind.trueFalse,
          prompt: 'The whale is white.',
          quizMode: QuizMode.grounded,
        ),
      ],
      generatedByProvider: AiProvider.groq,
      generatedByModel: 'qwen',
      confidence: 0.8,
    );

Widget _host({
  required FakeQuizCheckApi checkApi,
  required FakeSfxService sfx,
}) {
  final quiz = _quiz();
  final router = GoRouter(
    initialLocation: '/plan/p1/step/s1/quiz/qi1',
    routes: [
      GoRoute(
        path: '/plan/:planId/step/:stepId/quiz/:quizId',
        builder: (_, state) => QuizPage(
          planId: state.pathParameters['planId']!,
          stepId: state.pathParameters['stepId']!,
          quizId: state.pathParameters['quizId']!,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      quizGenControllerProvider.overrideWith(() => _SeededGen(quiz)),
      quizCheckApiProvider.overrideWithValue(checkApi),
      overrideSfxWith(sfx),
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

void main() {
  group('quiz check-banner flow', () {
    testWidgets('select → CHECK → success banner → CONTINUE advances',
        (tester) async {
      final checkApi =
          FakeQuizCheckApi(answerKey: {'q1': 'Ishmael', 'q2': 'True'});
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(checkApi: checkApi, sfx: sfx));
      await tester.pumpAndSettle();

      expect(find.text('Who narrates?'), findsOneWidget);
      // No banner before checking.
      expect(find.text('Nicely done!'), findsNothing);

      await tester.tap(find.text('Ishmael'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();

      // Instant-feedback banner + correct cue.
      expect(find.text('Nicely done!'), findsOneWidget);
      expect(sfx.played, contains(SoundEffect.correct));
      expect(find.text('CONTINUE'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Advanced to the second (last) question.
      expect(find.text('The whale is white.'), findsOneWidget);
    });

    testWidgets('a wrong answer shows the red banner with the correct answer',
        (tester) async {
      final checkApi =
          FakeQuizCheckApi(answerKey: {'q1': 'Ishmael', 'q2': 'True'});
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(checkApi: checkApi, sfx: sfx));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();

      expect(find.text('Not quite'), findsOneWidget);
      expect(find.textContaining('Ishmael'), findsWidgets);
      expect(sfx.played, contains(SoundEffect.wrong));
      // On the first (non-last) question the button reads CONTINUE.
      expect(find.text('CONTINUE'), findsOneWidget);
    });
  });
}
