import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/services/icon/app_icon_bridge.dart';
import 'package:owlnighter/shared/theme/theme_re_exports.dart';

/// Unit tests for the Dart→native launcher-icon bridge. These lock the
/// contract (channel name, method name, argument shape) that the native
/// Android side already implements, and confirm the bridge never throws even
/// when the platform channel isn't handled (unsupported platform, tests).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.owlnighter/app_icon');

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<List<MethodCall>> recordCalls() async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    return calls;
  }

  group('AppIconBridge.publish', () {
    test('idle sends setMood with mood: idle', () async {
      final calls = await recordCalls();
      await AppIconBridge.publish(OwlState.idle);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setMood');
      expect(calls.single.arguments, {'mood': 'idle'});
    });

    test('worried sends setMood with mood: worried', () async {
      final calls = await recordCalls();
      await AppIconBridge.publish(OwlState.worried);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setMood');
      expect(calls.single.arguments, {'mood': 'worried'});
    });

    test('angry sends setMood with mood: angry', () async {
      final calls = await recordCalls();
      await AppIconBridge.publish(OwlState.angry);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setMood');
      expect(calls.single.arguments, {'mood': 'angry'});
    });

    test('cheer sends setMood with mood: cheer', () async {
      final calls = await recordCalls();
      await AppIconBridge.publish(OwlState.cheer);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setMood');
      expect(calls.single.arguments, {'mood': 'cheer'});
    });

    test('never throws when no handler is registered (unsupported platform)',
        () async {
      // No mock handler set up at all -> the channel is unhandled, which
      // surfaces as a MissingPluginException. publish must swallow it.
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        AppIconBridge.publish(OwlState.cheer),
        completes,
      );
    });
  });
}
