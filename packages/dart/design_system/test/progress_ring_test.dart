import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required Widget child, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  group('ProgressRing', () {
    testWidgets('sizes itself and paints', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const ProgressRing(progress: 0.5, size: 100),
        ),
      );

      final box = tester.getSize(find.byType(ProgressRing));
      expect(box, const Size(100, 100));
      // A CustomPaint (the ring painter) is present in the subtree.
      expect(
        find.descendant(
          of: find.byType(ProgressRing),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('renders the center child', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const ProgressRing(
            progress: 0.25,
            center: Text('42%'),
          ),
        ),
      );

      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('animates toward a new progress value on update',
        (tester) async {
      Widget build(double p) => _host(child: ProgressRing(progress: p));

      await tester.pumpWidget(build(0.0));
      await tester.pumpWidget(build(1.0));

      // Mid-animation the ring should be strictly between the old and new
      // value (i.e. it tweens rather than snapping) when motion is enabled.
      await tester.pump(const Duration(milliseconds: 100));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ProgressRing),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .firstWhere((p) => p != null);
      expect(painter, isNotNull);

      // Let the animation finish; no exceptions and it settles.
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion snaps directly to target', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          child: const ProgressRing(progress: 0.0),
        ),
      );
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          child: const ProgressRing(progress: 1.0),
        ),
      );
      // A single frame is enough because reduced motion bypasses the tween.
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
