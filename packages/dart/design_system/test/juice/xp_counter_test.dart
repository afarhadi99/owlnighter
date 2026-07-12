import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('XpCounter', () {
    testWidgets('rolls up and lands on the final value', (tester) async {
      await tester.pumpWidget(
        _host(const XpCounter(value: 20, prefix: '+', suffix: ' XP')),
      );
      // Mid-roll the displayed number is below the target.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('+20 XP'), findsOneWidget);
    });

    testWidgets('reduced motion shows the final value immediately',
        (tester) async {
      await tester.pumpWidget(
        _host(reduceMotion: true, const XpCounter(value: 42)),
      );
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('animates to a new value on update', (tester) async {
      await tester.pumpWidget(
        _host(reduceMotion: true, const XpCounter(value: 10)),
      );
      expect(find.text('10'), findsOneWidget);
      await tester.pumpWidget(
        _host(reduceMotion: true, const XpCounter(value: 30)),
      );
      await tester.pump();
      expect(find.text('30'), findsOneWidget);
    });
  });
}
