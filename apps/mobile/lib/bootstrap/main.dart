import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../services/api/auth_repository_impl.dart';

/// App entry point. Runs inside a guarded [Zone] so uncaught async errors are
/// captured centrally, and restores any persisted session before first frame.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Surface Flutter framework errors through the same sink.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _reportError(details.exception, details.stack);
      };

      final container = ProviderContainer();

      // TODO(bootstrap): initialize Firebase + PushService here once native
      // Firebase config (google-services.json / GoogleService-Info.plist) is
      // added. Kept out of the critical path so the app boots without it.

      // Restore session from secure storage before we render (drives the
      // router's auth redirect on first frame).
      final restored = await container.read(authRepositoryProvider).restore();

      // Debug builds auto-enter as the seeded dev user so the app boots
      // straight into the core loop against the live local API. Release keeps
      // the real login path untouched.
      if (kDebugMode && restored == null) {
        await container.read(authRepositoryProvider).signInAsDev();
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const OwlnighterApp(),
        ),
      );
    },
    _reportError,
  );
}

void _reportError(Object error, StackTrace? stack) {
  // TODO(observability): forward to Sentry/Crashlytics. For now, log in debug.
  if (kDebugMode) {
    debugPrint('Uncaught error: $error\n$stack');
  }
}
