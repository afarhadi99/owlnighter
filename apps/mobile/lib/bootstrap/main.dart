import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/router.dart';
import '../services/api/auth_repository_impl.dart';
import '../services/api/extras_api.dart';
import '../services/notifications/notification_scheduler.dart';
import '../services/notifications/reminder_settings.dart';
import '../services/push/push_service.dart';
import '../services/widget/home_widget_bridge.dart';

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

      // Local notifications + timezone-correct scheduling. Fully functional
      // without any Firebase config — this drives the nightly-reminder feature.
      await _initLocalNotifications(container);

      // Restore session from secure storage before we render (drives the
      // router's auth redirect on first frame).
      final restored = await container.read(authRepositoryProvider).restore();

      // Debug builds auto-enter as the seeded dev user so the app boots
      // straight into the core loop against the live local API. Release keeps
      // the real login path untouched.
      if (kDebugMode && restored == null) {
        await container.read(authRepositoryProvider).signInAsDev();
      }

      // Firebase/FCM — gated so the app boots even without google-services.json.
      // Runs after auth so the token registers against a live session.
      await _initFirebaseMessaging(container);

      // Refresh the home-screen widget from the latest server stats (best
      // effort — offline or signed-out just leaves the last cached state).
      await _publishWidgetState(container);

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

/// Initialize the shared local-notifications plugin and re-arm the persisted
/// daily reminder. Notification taps (foreground/background and cold start)
/// deep-link into the router. Never throws — a missing plugin in an odd host
/// must not block boot.
Future<void> _initLocalNotifications(ProviderContainer container) async {
  try {
    NotificationScheduler.ensureTimezone();

    final plugin = container.read(localNotificationsProvider);
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          _routeFromNotification(container, response.payload),
    );

    // Cold start: the app was launched by tapping a scheduled reminder.
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _routeFromNotification(container, launch!.notificationResponse?.payload);
    }

    // Reading the controller re-loads the persisted preference and re-arms (or
    // cancels) the OS schedule.
    container.read(reminderControllerProvider.notifier);
  } catch (e, s) {
    if (kDebugMode) debugPrint('Local notifications unavailable: $e\n$s');
  }
}

/// Initialize Firebase + the FCM [PushService]. Gated in a try/catch: with no
/// google-services.json the native init throws and we skip push entirely rather
/// than crashing — local notifications still work.
Future<void> _initFirebaseMessaging(ProviderContainer container) async {
  try {
    await Firebase.initializeApp();
    await container.read(pushServiceProvider).init();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase/FCM not configured; push disabled (local '
          'notifications still active): $e');
    }
  }
}

/// Push the latest reading state into the Android home-screen widget on boot.
///
/// Reads `GET /v1/me/stats` (via the same [ExtrasApi] the streak tab uses) and
/// mirrors "did I read today" (last day in the trailing week) plus the current
/// streak into the widget. Never throws: no session, offline, or an
/// unregistered plugin all just leave whatever the widget last showed.
Future<void> _publishWidgetState(ProviderContainer container) async {
  try {
    final stats = await container.read(statsApiProvider).fetchStats();
    final readToday = stats.week.isNotEmpty && stats.week.last.read;
    await HomeWidgetBridge.publish(
      hasReadToday: readToday,
      currentStreak: stats.currentStreak,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Widget state publish skipped: $e');
  }
}

/// Route a tapped-notification [payload] (an in-app location or deep link)
/// into the router, if it resolves to a known location.
void _routeFromNotification(ProviderContainer container, String? payload) {
  if (payload == null || payload.isEmpty) return;
  final loc = locationForDeepLink(payload);
  if (loc != null) container.read(routerProvider).go(loc);
}

void _reportError(Object error, StackTrace? stack) {
  // TODO(observability): forward to Sentry/Crashlytics. For now, log in debug.
  if (kDebugMode) {
    debugPrint('Uncaught error: $error\n$stack');
  }
}
