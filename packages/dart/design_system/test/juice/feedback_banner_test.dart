import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('FeedbackBanner', () {
    testWidgets('success variant shows the title and check icon',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackBanner(
            kind: FeedbackKind.success,
            title: 'Nicely done!',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nicely done!'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('error variant shows the correct-answer detail line',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackBanner(
            kind: FeedbackKind.error,
            title: 'Not quite',
            correctAnswer: 'Genly Ai',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // The label + answer render in a RichText span.
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      expect(richText.text.toPlainText(), contains('Correct answer:'));
      expect(richText.text.toPlainText(), contains('Genly Ai'));
    });

    testWidgets('hosts a trailing action slot', (tester) async {
      // The ChunkyButton action fires a haptic before onPressed; give the
      // platform channel a handler so that await resolves in the test.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      var taps = 0;
      await tester.pumpWidget(
        _host(
          FeedbackBanner(
            kind: FeedbackKind.success,
            title: 'Done',
            action: ChunkyButton(
              label: 'Continue',
              variant: ChunkyButtonVariant.success,
              onPressed: () => taps++,
              fullWidth: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChunkyButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('reduced motion renders without a slide transition',
        (tester) async {
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          const FeedbackBanner(
            kind: FeedbackKind.success,
            title: 'Done',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
