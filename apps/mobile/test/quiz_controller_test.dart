import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/quiz/quiz_controller.dart';
import 'package:owlnighter/services/api/extras_api.dart';
import 'package:owlnighter/services/api/repository_providers.dart';

import 'support/fake_api.dart';

/// A stub quiz repository whose submit returns a canned result, so the
/// controller's submit path (core loop → streak) is testable without a network.
class _StubQuizRepo implements QuizRepository {
  _StubQuizRepo(this.result);
  final QuizResult result;
  List<QuizAnswer>? lastAnswers;

  @override
  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizAnswer> answers,
  }) async {
    lastAnswers = answers;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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

QuizResult _passResult() => const QuizResult(
      quizId: 'qi1',
      correctCount: 2,
      totalCount: 2,
      passed: true,
      markedComplete: true,
      perQuestion: [],
      streak: StreakState(currentStreak: 3, longestStreak: 5, xpGained: 20),
    );

void main() {
  group('QuizController', () {
    late ProviderContainer container;
    late _StubQuizRepo repo;
    late FakeQuizCheckApi checkApi;
    final quiz = _quiz();

    setUp(() {
      repo = _StubQuizRepo(_passResult());
      checkApi = FakeQuizCheckApi(
        answerKey: {'q1': 'Ishmael', 'q2': 'True'},
        explanation: 'Because the book says so.',
      );
      container = ProviderContainer(
        overrides: [
          quizRepositoryProvider.overrideWithValue(repo),
          quizCheckApiProvider.overrideWithValue(checkApi),
        ],
      );
    });
    tearDown(() => container.dispose());

    QuizController controller() =>
        container.read(quizControllerProvider(quiz).notifier);
    QuizUiState state() => container.read(quizControllerProvider(quiz));

    test('starts on the first question with an empty progress bar', () {
      final s = state();
      expect(s.currentIndex, 0);
      expect(s.current.id, 'q1');
      expect(s.isLast, isFalse);
      expect(s.progress, 0);
      expect(s.currentAnswered, isFalse);
    });

    test('answering records the choice; check grades it and fills progress',
        () async {
      final c = controller();
      c.answer('q1', 'Ishmael');
      expect(state().currentAnswered, isTrue);
      expect(state().currentChecked, isFalse);

      final verdict = await c.check();
      expect(verdict, isNotNull);
      expect(verdict!.correct, isTrue);
      expect(state().currentVerdict!.correct, isTrue);
      expect(state().currentChecked, isTrue);
      // One of two questions checked → half filled.
      expect(state().progress, closeTo(0.5, 1e-9));
      expect(checkApi.calls.single.questionId, 'q1');
    });

    test('a wrong answer reveals the correct one', () async {
      final c = controller();
      c.answer('q1', 'Ahab');
      final verdict = await c.check();
      expect(verdict!.correct, isFalse);
      expect(verdict.correctAnswer, 'Ishmael');
    });

    test('answers lock once checked (no silent re-answer)', () async {
      final c = controller();
      c.answer('q1', 'Ahab');
      await c.check();
      c.answer('q1', 'Ishmael'); // ignored after checking
      expect(state().answers['q1'], 'Ahab');
    });

    test('next only advances after the current question is checked', () async {
      final c = controller();
      c.next(); // no-op: not checked
      expect(state().currentIndex, 0);
      c.answer('q1', 'Ishmael');
      await c.check();
      c.next();
      expect(state().currentIndex, 1);
      expect(state().isLast, isTrue);
    });

    test('submit sends all answers and surfaces the streak result', () async {
      final c = controller();
      c.answer('q1', 'Ishmael');
      await c.check();
      c.next();
      c.answer('q2', 'True');
      await c.check();

      final result = await c.submit();

      expect(result, isNotNull);
      expect(result!.passed, isTrue);
      expect(result.streak.currentStreak, 3);
      expect(result.streak.xpGained, 20);
      expect(repo.lastAnswers, hasLength(2));
      expect(state().result, isNotNull);
      expect(state().submitting, isFalse);
      expect(state().correctSoFar, 2);
    });
  });
}
