import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline/offline.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/router.dart';
import '../../shared/util/platform_channel.dart';
import '../api/api_providers.dart';
import '../deep_links/deep_links.dart';
import '../notifications/reminder_settings.dart';
import '../offline_sync/offline_providers.dart';

/// Normalize a push/notification deep-link string to a go_router location.
/// Handles the `readingpath://` scheme and https universal links (via
/// [DeepLinks]) as well as payloads that are already an in-app location
/// (e.g. a scheduled local reminder's `/library`).
String? locationForDeepLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri != null && uri.hasScheme) return DeepLinks.toRouteLocation(uri);
  return link.startsWith('/') ? link : null;
}

/// Push notifications: FCM for remote delivery, flutter_local_notifications for
/// foreground display + local scheduled reminders. On a data message we record
/// it into the offline inbox and expose any deep link to the router.
class PushService {
  PushService({
    required this.messaging,
    required this.localNotifications,
    required this.cache,
    required this.onDeepLink,
    required this.registerToken,
  });

  final FirebaseMessaging messaging;
  final FlutterLocalNotificationsPlugin localNotifications;
  final OfflineCache cache;

  /// Called with a normalized deep-link URI string when a notification is opened.
  final void Function(String link) onDeepLink;

  /// Registers/updates the device token with the API.
  final Future<void> Function({
    required String token,
    required String platform,
    String? appVersion,
  }) registerToken;

  Future<void> init() async {
    await messaging.requestPermission();
    await _registerCurrentToken();
    messaging.onTokenRefresh.listen((t) => _register(t));

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _onOpened(initial);
  }

  Future<void> _registerCurrentToken() async {
    final token = await messaging.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    final info = await PackageInfo.fromPlatform();
    await registerToken(
      token: token,
      platform: currentPushPlatform(),
      appVersion: info.version,
    );
  }

  Future<void> _onForeground(RemoteMessage msg) async {
    await _recordInbox(msg);
    final n = msg.notification;
    if (n != null) {
      await localNotifications.show(
        msg.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'nightly',
            'Nightly reminders',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: _linkFrom(msg),
      );
    }
  }

  void _onOpened(RemoteMessage msg) {
    _recordInbox(msg);
    final link = _linkFrom(msg);
    if (link != null) onDeepLink(link);
  }

  /// Resolve a go_router location from a push payload. Prefers an explicit
  /// `deepLink` string; otherwise builds one from `planId` (+ optional
  /// `stepId`) — the shape a nightly-reminder push carries.
  static String? _linkFrom(RemoteMessage msg) {
    final explicit = msg.data['deepLink'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final planId = msg.data['planId'] as String?;
    if (planId == null || planId.isEmpty) return null;
    final stepId = msg.data['stepId'] as String?;
    return (stepId != null && stepId.isNotEmpty)
        ? DeepLinks.stepLink(planId, stepId).toString()
        : '$_scheme://plan/$planId';
  }

  static const String _scheme = DeepLinks.scheme;

  Future<void> _recordInbox(RemoteMessage msg) => cache.recordPush(
        messageId: msg.messageId ?? msg.hashCode.toString(),
        title: msg.notification?.title,
        body: msg.notification?.body,
        deepLink: msg.data['deepLink'] as String?,
        data: msg.data.isEmpty ? null : msg.data,
      );
}

/// Provider is created lazily by bootstrap once Firebase is initialized; the
/// deep-link callback is injected there so it can talk to the router.
final pushServiceProvider = Provider<PushService>((ref) {
  final api = ref.watch(apiProvider);
  return PushService(
    messaging: FirebaseMessaging.instance,
    localNotifications: ref.watch(localNotificationsProvider),
    cache: ref.watch(offlineCacheProvider),
    onDeepLink: (link) {
      final loc = locationForDeepLink(link);
      if (loc != null) ref.read(routerProvider).go(loc);
    },
    registerToken: ({required token, required platform, appVersion}) =>
        api.registerPushToken(
      token: token,
      platform: platform,
      appVersion: appVersion,
    ),
  );
});
