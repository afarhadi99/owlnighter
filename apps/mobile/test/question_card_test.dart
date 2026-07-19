import 'package:app_core/app_core.dart';
import 'package:design_system/design_system.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/quiz/question_card.dart';
import 'package:owlnighter/services/api/extras_api.dart';

/// Puts [child] inside a MaterialApp + Scaffold so QuestionCard's `Expanded`
/// (which needs a bounded height) and Material widgets (InkWell, TextField)
/// have the ancestry they require.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The border color of the answer card wrapping [label] — the redesign carries
/// each option's state (idle / selected / correct / wrong) in its card border.
Color _optionBorderColor(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return ((container.decoration! as BoxDecoration).border! as Border).top.color;
}

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

    testWidgets('selected option is highlighted; the others stay idle',
        (tester) async {
      await tester.pumpWidget(
        _host(
          QuestionCard(
            question: _mcQuestion(),
            selected: 'Ahab',
            onSelect: (_) {},
          ),
        ),
      );

      // The redesign lifts the picked option into the twilight-violet selected
      // state (indigo card border + filled letter key); the remaining two
      // options stay in the idle state (plain line border).
      expect(_optionBorderColor(tester, 'Ahab'), AppColors.indigo400);
      expect(_optionBorderColor(tester, 'Ishmael'), AppColors.line);
      expect(_optionBorderColor(tester, 'Queequeg'), AppColors.line);
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

      // The correct option turns green (success border) and its key box flips
      // to a ✓ badge; inputs are locked once checked.
      expect(_optionBorderColor(tester, 'Ishmael'), AppColors.successJuice);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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

      // Wrong pick → red (danger) card with a ✗ badge; the correct option is
      // revealed in green with a ✓ badge.
      expect(_optionBorderColor(tester, 'Ahab'), AppColors.danger500);
      expect(_optionBorderColor(tester, 'Ishmael'), AppColors.successJuice);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
