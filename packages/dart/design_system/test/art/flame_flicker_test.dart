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
  group('FlameFlicker', () {
    testWidgets('flickers without exceptions and exposes an a11y label',
        (tester) async {
      await tester.pumpWidget(_host(const FlameFlicker(intensity: 0.8)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FlameFlicker), findsOneWidget);
      expect(
        find.bySemanticsLabel('Streak flame, intensity 80 percent'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps out-of-range intensity', (tester) async {
      await tester.pumpWidget(_host(const FlameFlicker(intensity: 5)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.bySemanticsLabel('Streak flame, intensity 100 percent'),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion renders a static flame (settles)',
        (tester) async {
      await tester.pumpWidget(
        _host(const FlameFlicker(intensity: 0.5), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlameFlicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation does not throw', (tester) async {
      await tester.pumpWidget(_host(const FlameFlicker(intensity: 0.9)));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('StreakFlame (delegates to FlameFlicker)', () {
    testWidgets('active streak renders a lit flame', (tester) async {
      await tester.pumpWidget(_host(const StreakFlame(streakCount: 3)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FlameFlicker), findsOneWidget);
      expect(find.bySemanticsLabel('Streak active, 3 days'), findsOneWidget);
    });

    testWidgets('singular day label for a one-day streak', (tester) async {
      await tester.pumpWidget(_host(const StreakFlame(streakCount: 1)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Streak active, 1 day'), findsOneWidget);
    });

    testWidgets('zero streak renders the inactive ember', (tester) async {
      await tester.pumpWidget(_host(const StreakFlame(streakCount: 0)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Streak inactive'), findsOneWidget);
    });

    test('isActive reflects the streak count', () {
      expect(const StreakFlame(streakCount: 1).isActive, isTrue);
      expect(const StreakFlame(streakCount: 0).isActive, isFalse);
    });
  });
}
