import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

/// FCM background-isolate entry point.
///
/// Runs in a separate isolate when a push arrives while the app is
/// backgrounded or terminated. Must be a top-level function and
/// annotated with @pragma('vm:entry-point') so Flutter's tree-shaker
/// doesn't drop it from release builds. We re-init Firebase because
/// the new isolate doesn't share the main isolate's instances.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('[fcm-bg] received: ${message.messageId}');
  }
  // System tray rendering is handled by FCM itself when the payload
  // includes a `notification` block (Cloud Functions does). Nothing
  // more to do here — keep this lean.
}

// Pass via `flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxx`
// or set in your IDE run config. Empty default keeps the app runnable
// without a token — the map screen degrades gracefully.
const _mapboxAccessToken =
    String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check — debug provider in debug builds (so emulator/CI keep working
  // without Play Integrity / DeviceCheck), Play Integrity / DeviceCheck for
  // release. Failures are swallowed so a broken provider never blocks
  // launch — backend enforcement is the source of truth.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider()
          : AppleDeviceCheckProvider(),
    );
  } catch (_) {
    // App Check init failed (no token, network blip, unsupported platform).
    // App still runs; rules will gate writes once Enforce is on in console.
  }

  if (_mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxAccessToken);
  }

  // Register the FCM background handler BEFORE runApp. Doing this
  // after the framework attaches will silently drop pushes that
  // arrive while the app is launching.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Foreground notification service is initialised lazily inside the
  // first authenticated build of PetaFindsApp — the token write
  // requires a signed-in uid, so booting it here would just no-op.

  runApp(const ProviderScope(child: PetaFindsApp()));
}

bool get hasMapboxToken => _mapboxAccessToken.isNotEmpty;

class PetaFindsApp extends ConsumerStatefulWidget {
  const PetaFindsApp({super.key});

  @override
  ConsumerState<PetaFindsApp> createState() => _PetaFindsAppState();
}

class _PetaFindsAppState extends ConsumerState<PetaFindsApp> {
  bool _fcmInitFired = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Bootstrap FCM exactly once after a user signs in. Firebase Auth
    // state can flip null↔user multiple times during startup (anonymous
    // → restore-from-keychain), so we gate on a non-null uid and a
    // local one-shot flag.
    final authedUid =
        FirebaseAuth.instance.currentUser?.uid;
    if (!_fcmInitFired && authedUid != null) {
      _fcmInitFired = true;
      // Don't await — the rest of the app shouldn't wait on push
      // setup. Permission prompt + token persist happen in parallel.
      NotificationService.instance.initialize();
    }
    // Re-arm if the user signs out + back in within this session.
    if (authedUid == null && _fcmInitFired) {
      _fcmInitFired = false;
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}