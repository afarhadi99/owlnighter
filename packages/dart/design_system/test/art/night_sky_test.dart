import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 300, height: 600, child: child),
      ),
    );

void main() {
  group('NightSky', () {
    testWidgets('renders and animates without exceptions', (tester) async {
      await tester.pumpWidget(_host(const NightSky(seed: 3, starCount: 30)));
      // Let the twinkle controller tick a few frames.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NightSky), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders a static sky (settles)',
        (tester) async {
      await tester.pumpWidget(
        _host(const NightSky(seed: 3), reduceMotion: true),
      );
      // With no ticking controller, the tree settles.
      await tester.pumpAndSettle();
      expect(find.byType(NightSky), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('layers a child above the sky', (tester) async {
      await tester.pumpWidget(
        _host(const NightSky(child: Text('hello moon'))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('hello moon'), findsOneWidget);
    });

    testWidgets('disposing mid-animation does not throw', (tester) async {
      await tester.pumpWidget(_host(const NightSky()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
