import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/quiz/question_card.dart';
import 'package:owlnighter/services/api/extras_api.dart';

/// Puts [child] inside a MaterialApp + Scaffold so QuestionCard's `Expanded`
/// (which needs a bounded height) and Material widgets (InkWell, TextField)
/// have the ancestry they require.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

QuizQuestion _mcQuestion() => const QuizQuestion(
      id: 'q1',
      kind: QuizQuestionKind.multipleChoice,
      prompt: 'Who narrates the story?',
      quizMode: QuizMode.grounded,
      options: ['Ishmael', 'Ahab', 'Queequeg'],
    );

void main() {
  group('QuestionCard', () {
    testWidgets('renders prompt, mode badge, and all options', (tester) async {
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: null,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('Who narrates the story?'), findsOneWidget);
      // Grounded mode badge label (see QuizModeBadge).
      expect(find.text('Grounded'), findsOneWidget);
      expect(find.text('Ishmael'), findsOneWidget);
      expect(find.text('Ahab'), findsOneWidget);
      expect(find.text('Queequeg'), findsOneWidget);
    });

    testWidgets('tapping an option reports its value via onSelect',
        (tester) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: null,
            onSelect: (v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.text('Queequeg'));
      await tester.pump();

      expect(picked, 'Queequeg');
    });

    testWidgets('selected option shows the checked radio icon', (tester) async {
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: 'Ahab',
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      // Two remaining unselected options.
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(2),
      );
    });

    testWidgets('a correct verdict restyles the chosen option green',
        (tester) async {
      bool selectedAgain = false;
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: 'Ishmael',
            verdict: const QuizCheckResult(
              correct: true,
              correctAnswer: 'Ishmael',
            ),
            onSelect: (_) => selectedAgain = true,
          ),
        ),
      );

      // The correct option shows the green check-circle; inputs are locked.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.tap(find.text('Ishmael'));
      await tester.pump();
      expect(selectedAgain, isFalse);
    });

    testWidgets('a wrong verdict marks the pick red and reveals the answer',
        (tester) async {
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: 'Ahab',
            verdict: const QuizCheckResult(
              correct: false,
              correctAnswer: 'Ishmael',
            ),
            onSelect: (_) {},
          ),
        ),
      );

      // Wrong pick → red cancel icon; correct option → green check-circle.
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('true/false question renders exactly True and False',
        (tester) async {
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: const QuizQuestion(
              id: 'q2',
              kind: QuizQuestionKind.trueFalse,
              prompt: 'The whale is white.',
              quizMode: QuizMode.preview,
            ),
            selected: null,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('True'), findsOneWidget);
      expect(find.text('False'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('short answer renders a text field that reports input',
        (tester) async {
      String? typed;
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: const QuizQuestion(
              id: 'q3',
              kind: QuizQuestionKind.shortAnswer,
              prompt: 'Summarize the chapter.',
              quizMode: QuizMode.userText,
            ),
            selected: null,
            onSelect: (v) => typed = v,
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A sea voyage.');
      expect(typed, 'A sea voyage.');
      // userText mode badge label.
      expect(find.text('Your pages'), findsOneWidget);
    });
  });
}
