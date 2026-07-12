import 'dart:math' as math;

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
  group('OwlMascot', () {
    testWidgets('renders idle and breathes without exceptions', (tester) async {
      await tester.pumpWidget(_host(const OwlMascot()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(find.bySemanticsLabel('Owl mascot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('transitions between states without exceptions',
        (tester) async {
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.idle)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.cheer)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.sleepy)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders a static owl (settles)',
        (tester) async {
      await tester.pumpWidget(
        _host(const OwlMascot(state: OwlState.sleepy), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation does not throw', (tester) async {
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.cheer)));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('new greet state peeks and settles without exceptions',
        (tester) async {
      // Enter greet from idle so the one-shot transition/peek plays.
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.idle)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_host(const OwlMascot(state: OwlState.greet)));
      // Peek rise…
      await tester.pump(const Duration(milliseconds: 150));
      // …and settle.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('greet renders a charming static owl under reduced motion',
        (tester) async {
      await tester.pumpWidget(
        _host(const OwlMascot(state: OwlState.greet), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'jittered idle runs over a long stretch with an injected fixed Random',
        (tester) async {
      // A seeded Random makes the blink/micro-tilt cadence deterministic, so
      // this exercises the full jitter scheduling path (multiple reschedules)
      // without flakiness.
      await tester.pumpWidget(
        _host(OwlMascot(state: OwlState.idle, random: math.Random(42))),
      );
      // Pump ~20s of animation in small frames to cross several blink windows
      // and at least one micro head-tilt reschedule (6-10s cadence).
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts an injected Random additively (no behavior break)',
        (tester) async {
      // Same seed → constructs and animates fine; proves the param is additive.
      await tester.pumpWidget(
        _host(OwlMascot(random: math.Random(1))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OwlMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
