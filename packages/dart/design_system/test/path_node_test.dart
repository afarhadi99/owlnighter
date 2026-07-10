import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal ancestry for a PathNode: it uses Material Icons + Semantics and
/// reads reduced-motion from MediaQuery.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('PathNode', () {
    testWidgets('available node is tappable and shows the book icon',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PathNode(
            status: PathNodeStatus.available,
            label: 'Night 1',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      await tester.tap(find.byType(PathNode));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('locked node ignores taps and shows the lock icon',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PathNode(
            status: PathNodeStatus.locked,
            label: 'Night 5',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.byType(PathNode), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('completed node shows the check icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const PathNode(
            status: PathNodeStatus.completed,
            label: 'Night 2',
          ),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
