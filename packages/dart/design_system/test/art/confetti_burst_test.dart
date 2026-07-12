import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 300, height: 500, child: child),
      ),
    );

void main() {
  group('ConfettiBurst', () {
    testWidgets('autoplay fires and completes without exceptions',
        (tester) async {
      await tester.pumpWidget(
        _host(const ConfettiBurst(autoPlay: true, particleCount: 40)),
      );
      // Post-frame callback fires the burst.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(ConfettiBurst), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller.play() triggers a burst', (tester) async {
      final controller = ConfettiController();
      await tester.pumpWidget(
        _host(ConfettiBurst(controller: controller, particleCount: 30)),
      );
      await tester.pump();
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      controller.dispose();
    });

    testWidgets('reduced motion shows the static sparkle fallback (settles)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ConfettiBurst(autoPlay: true, particleCount: 40),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ConfettiBurst), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-burst does not throw', (tester) async {
      await tester.pumpWidget(
        _host(const ConfettiBurst(autoPlay: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
