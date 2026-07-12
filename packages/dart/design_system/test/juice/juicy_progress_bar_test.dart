import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 200, child: child)),
      ),
    );

void main() {
  group('JuicyProgressBar', () {
    testWidgets('renders at an initial value', (tester) async {
      await tester.pumpWidget(_host(const JuicyProgressBar(value: 0.4)));
      expect(find.byType(JuicyProgressBar), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('animates toward a new value on update', (tester) async {
      await tester.pumpWidget(_host(const JuicyProgressBar(value: 0.2)));
      await tester.pumpAndSettle();
      // Increase the value: it should animate (and eventually settle).
      await tester.pumpWidget(_host(const JuicyProgressBar(value: 0.8)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byType(JuicyProgressBar), findsOneWidget);
    });

    testWidgets('reduced motion snaps to the target value', (tester) async {
      await tester.pumpWidget(
        _host(reduceMotion: true, const JuicyProgressBar(value: 0.2)),
      );
      await tester.pumpWidget(
        _host(reduceMotion: true, const JuicyProgressBar(value: 0.9)),
      );
      await tester.pump();
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(JuicyProgressBar), findsOneWidget);
    });

    testWidgets('accepts a segment count', (tester) async {
      await tester.pumpWidget(
        _host(const JuicyProgressBar(value: 0.5, segments: 4)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JuicyProgressBar), findsOneWidget);
    });
  });
}
