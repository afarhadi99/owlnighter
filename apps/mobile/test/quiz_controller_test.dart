import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/quiz/quiz_controller.dart';
import 'package:owlnighter/services/api/repository_providers.dart';

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
    final quiz = _quiz();

    setUp(() {
      repo = _StubQuizRepo(_passResult());
      container = ProviderContainer(
        overrides: [quizRepositoryProvider.overrideWithValue(repo)],
      );
    });
    tearDown(() => container.dispose());

    QuizController controller() =>
        container.read(quizControllerProvider(quiz).notifier);
    QuizUiState state() => container.read(quizControllerProvider(quiz));

    test('starts on the first question with correct progress', () {
      final s = state();
      expect(s.currentIndex, 0);
      expect(s.current.id, 'q1');
      expect(s.isLast, isFalse);
      expect(s.progress, closeTo(0.5, 1e-9));
      expect(s.currentAnswered, isFalse);
    });

    test('answering records the choice and enables advancing', () {
      controller().answer('q1', 'Ishmael');
      expect(state().answers['q1'], 'Ishmael');
      expect(state().currentAnswered, isTrue);
    });

    test('next/back navigate and clamp at the ends', () {
      final c = controller();
      c.back(); // no-op at start
      expect(state().currentIndex, 0);
      c.next();
      expect(state().currentIndex, 1);
      expect(state().isLast, isTrue);
      c.next(); // no-op at end
      expect(state().currentIndex, 1);
      c.back();
      expect(state().currentIndex, 0);
    });

    test('submit sends all answers and surfaces the streak result', () async {
      final c = controller();
      c.answer('q1', 'Ishmael');
      c.next();
      c.answer('q2', 'True');

      final result = await c.submit();

      expect(result, isNotNull);
      expect(result!.passed, isTrue);
      expect(result.streak.currentStreak, 3);
      expect(result.streak.xpGained, 20);
      // The controller forwarded both answers to the repository.
      expect(repo.lastAnswers, hasLength(2));
      expect(state().result, isNotNull);
      expect(state().submitting, isFalse);
    });
  });
}
