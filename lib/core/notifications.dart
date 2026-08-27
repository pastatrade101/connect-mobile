import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

/// Android hands a background message to a fresh isolate, so this has to be a
/// top-level function. Nothing to do here: the system tray already shows the
/// notification Firebase delivered — this only keeps the plugin happy.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// Getting told, without opening the app.
///
/// Two halves, deliberately separable:
///
///   • PUSH — the server sends Firebase messages to whoever holds a thread (see
///     `push.ts` in Connect). [connectPush] asks Firebase for this device's token
///     and registers it against the account. It needs the Firebase config files to
///     be present (google-services.json / GoogleService-Info.plist); without them
///     Firebase refuses to start and we say so quietly rather than crashing.
///
///   • POLLING — the honest fallback while the app is open: one small request a
///     minute, raising a real system notification for anything new. It stops the
///     moment a push token is registered, and covers the iOS Simulator, which can
///     never receive a real remote notification.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapped = StreamController<String>.broadcast();
  Timer? _poller;
  final Set<String> _seen = <String>{};
  bool _ready = false;
  bool _pushAttached = false;

  /// Conversation ids the user opened from a notification.
  Stream<String> get onOpenConversation => _tapped.stream;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) _tapped.add(id);
      },
    );

    // Android 13+ asks; older versions grant at install.
    final android_ = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android_?.requestNotificationsPermission();
    // The server addresses pushes to this channel by name, so it must exist before
    // the first one arrives — Android silently drops notifications for unknown ones.
    await android_?.createNotificationChannel(
      const AndroidNotificationChannel(
        'makutano_inbox',
        'Inbox',
        description: 'New WhatsApp messages assigned to you',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  /// Ask Firebase for this device's address and give it to Connect.
  ///
  /// Everything here is best-effort by design: a missing Firebase project, a
  /// declined permission prompt or a simulator with no APNs registration all end
  /// the same way — polling keeps working and nobody sees an error.
  Future<bool> connectPush() async {
    if (_pushAttached) return true;
    if (!Api.instance.signedIn) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (error) {
      debugPrint('[notifications] no Firebase project on this build: $error');
      return false;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[notifications] push permission declined');
        return false;
      }
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      // iOS hands out an FCM token only once APNs has registered the device; the
      // Simulator never does, so this stays null there and polling carries on.
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return false;

      // A foreground message would otherwise be swallowed, so show it ourselves.
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        unawaited(
          _show(
            title: notification.title ?? 'Makutano Connect',
            body: notification.body ?? '',
            conversationId: (message.data['conversationId'] ?? '').toString(),
          ),
        );
      });
      // Tapped from the tray, either while running or from cold.
      FirebaseMessaging.onMessageOpenedApp.listen(_routeFrom);
      final launch = await messaging.getInitialMessage();
      if (launch != null) _routeFrom(launch);
      // Tokens rotate; the account has to follow.
      messaging.onTokenRefresh.listen((next) {
        unawaited(attachPushToken(next, platform: _platform));
      });

      await attachPushToken(token, platform: _platform);
      return _pushAttached;
    } catch (error) {
      debugPrint('[notifications] push unavailable: $error');
      return false;
    }
  }

  void _routeFrom(RemoteMessage message) {
    final id = (message.data['conversationId'] ?? '').toString();
    if (id.isNotEmpty) _tapped.add(id);
  }

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Wire a real FCM token to the account. Safe to call more than once.
  Future<void> attachPushToken(String token, {String? platform, String? deviceName}) async {
    try {
      await Api.instance.registerDevice(token, platform: platform ?? _platform, deviceName: deviceName);
      _pushAttached = true;
      stopWatching(); // the server takes over from here
    } catch (error) {
      debugPrint('[notifications] could not register device: $error');
    }
  }

  /// Poll the inbox for anything unread that we have not already announced.
  void startWatching({Duration every = const Duration(seconds: 45)}) {
    if (_pushAttached || _poller != null) return;
    _poller = Timer.periodic(every, (_) => _check());
    unawaited(_check(silent: true)); // first pass only learns the current state
  }

  void stopWatching() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _check({bool silent = false}) async {
    if (!Api.instance.signedIn) return;
    try {
      final data = await Api.instance.inbox();
      final threads = (data['threads'] as List? ?? const []);
      for (final raw in threads) {
        final thread = raw as Map<String, dynamic>;
        final unread = (thread['unread'] as num? ?? 0).toInt();
        if (unread <= 0) continue;
        // The key changes whenever the count does, so a second message on the same
        // thread notifies again but the same state never notifies twice.
        final key = '${thread['id']}:$unread';
        if (_seen.contains(key)) continue;
        _seen.add(key);
        if (silent) continue;
        await _show(
          title: (thread['name'] ?? 'New message').toString(),
          body: (thread['preview'] ?? 'Sent you a message').toString(),
          conversationId: (thread['id'] ?? '').toString(),
        );
      }
    } catch (error) {
      debugPrint('[notifications] poll failed: $error');
    }
  }

  Future<void> _show({required String title, required String body, required String conversationId}) async {
    const android = AndroidNotificationDetails(
      'makutano_inbox',
      'Inbox',
      channelDescription: 'New WhatsApp messages assigned to you',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true);
    await _plugin.show(
      conversationId.hashCode & 0x7fffffff,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
      payload: conversationId,
    );
  }
}
