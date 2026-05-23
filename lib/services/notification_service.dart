import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart' show rootNavigatorKey;

/// One-stop integration for Firebase Cloud Messaging.
///
/// Responsibilities:
///   1. Ask the OS for notification permission (iOS prompts; Android
///      13+ also prompts since API 33).
///   2. Fetch the device FCM token and write it to
///      /users/{uid}.fcmToken so Cloud Functions can target the
///      device when something interesting happens server-side.
///   3. Wire the three FCM lifecycle streams:
///        - onMessage (foreground)        → show a local-notification
///        - onMessageOpenedApp (bg tap)   → deep-link
///        - getInitialMessage (cold tap)  → deep-link
///   4. Track token refresh and re-save.
///
/// Tap routing follows a simple `data.type` + `data.id` convention
/// matched by every Cloud Function in functions/index.js:
///   - type 'message'  → /chat/{convId}
///   - type 'review'   → /home/business/{businessId}  (and product
///                       variant: /home/product/{productId})
///   - type 'approval' → /business
///
/// Singleton — call NotificationService.initialize() once at app
/// startup AFTER the user is signed in (the token write requires a
/// uid). main.dart also registers the background isolate handler
/// via FirebaseMessaging.onBackgroundMessage.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android channel id matches the one declared in the manifest
  /// + AndroidManifest meta-data. Keep in sync if you rename.
  static const _androidChannelId = 'petafinds_default';
  static const _androidChannelName = 'PetaFinds';
  static const _androidChannelDescription =
      'Chat, review, and approval notifications.';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1) Request OS permission.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint(
          '[fcm] permission status: ${settings.authorizationStatus}');
    }

    // 2) Local-notification plugin — shows the foreground push as a
    //    system banner the user can tap.
    await _initLocal();

    // 3) iOS foreground presentation options — without these the
    //    banner doesn't appear when the app is open.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4) Token bootstrap + refresh listener.
    await _persistToken();
    _messaging.onTokenRefresh.listen((_) => _persistToken());

    // 5) Foreground / opened-from-background / cold-start streams.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Defer to next frame so the router is mounted before we try
      // to navigate.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleNotificationTap(initial));
    }
  }

  // ---------------------------------------------------------------------------
  // Local notifications
  // ---------------------------------------------------------------------------

  Future<void> _initLocal() async {
    const android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        // Tapping a local-notif banner re-uses the same routing path
        // as a real FCM tap. payload is `${type}|${id}`.
        final raw = resp.payload;
        if (raw == null) return;
        final parts = raw.split('|');
        if (parts.length != 2) return;
        _routeFor(type: parts[0], id: parts[1]);
      },
    );

    // Android needs the channel explicitly created.
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    final data = message.data;
    if (notif == null) return;
    // Show the system banner via flutter_local_notifications so the
    // foreground experience matches the background one.
    _local.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: '${data['type'] ?? ''}|${data['id'] ?? ''}',
    );
  }

  // ---------------------------------------------------------------------------
  // Token persistence
  // ---------------------------------------------------------------------------

  Future<void> _persistToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Most common cause: Firestore rule rejects the update because
      // the user doc was just created and the keys-allowlist hadn't
      // propagated yet. Non-fatal; the next refresh will retry.
      debugPrint('[fcm] persistToken failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Tap routing
  // ---------------------------------------------------------------------------

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    final id = data['id']?.toString();
    if (type == null || id == null) return;
    _routeFor(type: type, id: id);
  }

  void _routeFor({required String type, required String id}) {
    final navState = rootNavigatorKey.currentState;
    final ctx = navState?.context;
    if (ctx == null) return;
    switch (type) {
      case 'message':
        ctx.go('/chat/$id');
        break;
      case 'review':
        // Reviews can be on businesses or products. The Cloud Function
        // pushes one of: id = businessId (onNewReview) OR productId
        // (onNewProductReview). Routing to /home/business/{id} works
        // for businesses; product reviews land users on the business
        // detail screen too — that's a small concession to avoid a
        // second `data` field. Tighten with subtype later.
        ctx.go('/home/business/$id');
        break;
      case 'approval':
        ctx.go('/business');
        break;
      default:
        // Unknown type — ignore. Don't crash.
        break;
    }
  }
}
