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
  });
}
