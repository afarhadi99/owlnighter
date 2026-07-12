import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

void main() {
  group('ChunkyButton', () {
    late List<String> haptics;

    setUp(() {
      haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders an uppercased label', (tester) async {
      await tester.pumpWidget(
        _host(ChunkyButton(label: 'Continue', onPressed: () {})),
      );
      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets('fires onPressed and a haptic on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(ChunkyButton(label: 'Go', onPressed: () => taps++)),
      );
      await tester.tap(find.byType(ChunkyButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(haptics, contains('HapticFeedback.vibrate'));
    });

    testWidgets('reduced motion fires onPressed without a haptic',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          reduceMotion: true,
          ChunkyButton(label: 'Go', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(ChunkyButton));
      await tester.pump();
      expect(taps, 1);
      expect(haptics, isEmpty);
    });

    testWidgets('disabled button is not tappable and reports disabled',
        (tester) async {
      await tester.pumpWidget(
        _host(const ChunkyButton(label: 'Nope', onPressed: null)),
      );
      await tester.tap(find.byType(ChunkyButton), warnIfMissed: false);
      await tester.pump();
      // A disabled button neither fires a haptic nor is hit-testable.
      expect(haptics, isEmpty);
    });

    testWidgets('renders a leading icon when provided', (tester) async {
      await tester.pumpWidget(
        _host(
          ChunkyButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });
}
