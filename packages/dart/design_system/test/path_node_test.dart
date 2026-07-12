import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal ancestry for a PathNode: it uses Material Icons + Semantics and
/// reads reduced-motion from MediaQuery. Reduced motion is forced by default so
/// the available/current pulse loop doesn't keep scheduling frames (which would
/// hang pumpAndSettle); individual tests opt back into motion where relevant.
Widget _host(Widget child, {bool reduceMotion = true}) => MediaQuery(
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

    testWidgets('available node shows the localizable START callout',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const PathNode(
            status: PathNodeStatus.available,
            label: 'Night 1',
            startLabel: 'Empezar',
          ),
        ),
      );
      // Uppercased in the pill.
      expect(find.text('EMPEZAR'), findsOneWidget);
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

    testWidgets('current node shows the in-progress book icon', (tester) async {
      await tester.pumpWidget(
        _host(
          const PathNode(
            status: PathNodeStatus.current,
            label: 'Night 3',
            progress: 0.5,
          ),
        ),
      );
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('press fires a light-impact haptic when motion is on',
        (tester) async {
      final haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.method);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _host(
          reduceMotion: false,
          PathNode(
            status: PathNodeStatus.completed,
            label: 'Night 2',
            onTap: () {},
          ),
        ),
      );
      await tester.tap(find.byType(PathNode));
      await tester.pump();
      expect(haptics, contains('HapticFeedback.vibrate'));
    });
  });
}
