import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 300, height: 700, child: child),
      ),
    );

void main() {
  group('PathScenery', () {
    testWidgets('renders, twinkles, and ignores pointers', (tester) async {
      await tester.pumpWidget(_host(const PathScenery(starCount: 40)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PathScenery), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('parallax tracks scrollOffset changes', (tester) async {
      await tester.pumpWidget(
        _host(const PathScenery(scrollOffset: 0, starCount: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(
        _host(const PathScenery(scrollOffset: 240, starCount: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders a static field (settles)',
        (tester) async {
      await tester.pumpWidget(
        _host(const PathScenery(starCount: 30), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PathScenery), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation does not throw', (tester) async {
      await tester.pumpWidget(_host(const PathScenery()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
