import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

/// Getting told, without opening the app.
///
/// Two halves, deliberately separable:
///
///   • The SERVER already sends Firebase messages to whoever holds a thread (see
///     `push.ts` in Connect). Add `firebase_messaging` plus this project's
///     google-services.json and call [Notifications.instance.attachPushToken] with
///     the FCM token — the backend endpoint for it already exists.
///
///   • Until then this watcher polls the inbox while the app is alive and raises a
///     real system notification for anything new. It is the honest fallback: it
///     works today, it costs one small request a minute, and it disappears the
///     moment a real push token is attached.
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
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Wire a real FCM token to the account. Safe to call more than once.
  Future<void> attachPushToken(String token, {String platform = 'android', String? deviceName}) async {
    try {
      await Api.instance.registerDevice(token, platform: platform, deviceName: deviceName);
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
