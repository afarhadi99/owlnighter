import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Under reduced motion the flame renders the static placeholder (no Rive
/// asset needed), which is exactly the path a widget test can assert on.
Widget _host(Widget child) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('StreakFlame (reduced-motion placeholder)', () {
    testWidgets('active streak shows the lit flame with an active label',
        (tester) async {
      await tester.pumpWidget(_host(const StreakFlame(streakCount: 3)));
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Streak active'), findsOneWidget);
    });

    testWidgets('zero streak renders the inactive placeholder', (tester) async {
      await tester.pumpWidget(_host(const StreakFlame(streakCount: 0)));
      expect(find.bySemanticsLabel('Streak inactive'), findsOneWidget);
    });

    test('isActive reflects the streak count', () {
      expect(const StreakFlame(streakCount: 1).isActive, isTrue);
      expect(const StreakFlame(streakCount: 0).isActive, isFalse);
    });
  });
}
