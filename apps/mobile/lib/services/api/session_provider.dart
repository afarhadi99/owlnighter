import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the app-wide [SessionController]. Its lifecycle spans the app, so it
/// lives in a keep-alive Provider and is disposed with the ProviderContainer.
final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Reactive auth state derived from the controller's change stream. Features
/// watch this to redirect between auth and the main shell.
final authStateProvider = StreamProvider<AuthSession?>((ref) {
  final controller = ref.watch(sessionControllerProvider);
  // Seed with the current value, then follow the stream.
  return controller.changes.startWith(controller.session);
});

extension _StartWith<T> on Stream<T> {
  /// Emit [initial] before the underlying stream's events. Small local helper
  /// so we don't pull in rxdart for one operator.
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
