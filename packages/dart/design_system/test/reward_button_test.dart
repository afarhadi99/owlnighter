import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimal ancestry RewardButton needs, letting a test
/// force the OS reduced-motion flag via [disableAnimations].
Widget _host({required Widget child, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

/// A tappable, painted target — an empty SizedBox is not hit-testable under
/// GestureDetector's default `deferToChild` behavior.
Widget _target() => const ColoredBox(
      color: Color(0xFF000000),
      child: SizedBox(width: 80, height: 40),
    );

void main() {
  group('RewardButton', () {
    late List<String> hapticMethods;

    setUp(() {
      hapticMethods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        // HapticFeedback.mediumImpact() invokes 'HapticFeedback.vibrate'.
        if (call.method == 'HapticFeedback.vibrate') {
          hapticMethods.add(call.method);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('fires onTap and plays the press animation with haptic',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          child: RewardButton(onTap: () => taps++, child: _target()),
        ),
      );

      await tester.tap(find.byType(RewardButton));
      // Drive the forward (120ms) + reverse (90ms) scale animation + haptic.
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(hapticMethods, contains('HapticFeedback.vibrate'));
    });

    testWidgets('reduced motion: fires onTap immediately and skips haptic',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          child: RewardButton(onTap: () => taps++, child: _target()),
        ),
      );

      await tester.tap(find.byType(RewardButton));
      await tester.pump();

      expect(taps, 1);
      // Reduced motion routes GestureDetector straight to onTap: no haptic.
      expect(hapticMethods, isEmpty);
    });
  });
}
