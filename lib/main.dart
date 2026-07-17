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
import 'core/theme/app_colors.dart';
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

  // Silence debugPrint in release builds. The codebase logs liberally
  // (router redirects, auth flow, chat) which is invaluable in debug but
  // in release each call still formats + throttle-prints to os_log/logcat
  // — measurable overhead on hot paths like the router redirect that runs
  // on every navigation. One assignment here beats guarding 170+ sites.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check — debug provider in debug builds (so emulator/CI keep working
  // without Play Integrity / DeviceCheck), Play Integrity / DeviceCheck for
  // release.
  //
  // Pass --dart-define=USE_DEBUG_APP_CHECK=true in a Codemagic release build
  // to force the debug provider while Play Integrity API is being configured
  // in Google Cloud Console. Remove the dart-define once Play Integrity tokens
  // are confirmed working.
  const bool forceDebugAppCheck =
      bool.fromEnvironment('USE_DEBUG_APP_CHECK', defaultValue: false);
  final bool useDebugProvider = kDebugMode || forceDebugAppCheck;

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugProvider
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
      providerApple: useDebugProvider
          ? AppleDebugProvider()
          : AppleDeviceCheckProvider(),
    );
    debugPrint(
      '[AppCheck] activated — provider: ${useDebugProvider ? "DEBUG" : "Play Integrity / DeviceCheck"}',
    );
  } catch (e) {
    // App Check init failed (no token, network blip, unsupported platform).
    // App still runs; rules will gate writes once Enforce is on in console.
    debugPrint('[AppCheck] activation FAILED: $e');
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

    // Dark mode is temporarily turned off app-wide: the settings toggle is
    // hidden (see DarkModeSection in widgets/dark_mode_tile.dart) and we force
    // the light palette for everyone — this also frees any user who had dark
    // saved in prefs but can no longer reach the switch. The whole theming
    // system stays in place (theme_controller.dart, AppColors, the shell
    // watches). To bring dark mode back, restore:
    //   final savedMode = ref.watch(themeModeProvider);
    //   final isAdmin = ref.watch(appUserProvider).valueOrNull?.isAdmin ?? false;
    //   final effectiveMode = isAdmin ? ThemeMode.light : savedMode;
    // and re-add the DarkModeSection toggle in the settings screens.
    const effectiveMode = ThemeMode.light;
    appBrightness = Brightness.light;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      // AppTheme.light is fully adaptive — it reads appBrightness, so it is
      // the correct ThemeData for whichever mode is active. Passing it as
      // both theme + darkTheme keeps MaterialApp's own brightness aligned.
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: effectiveMode,
      routerConfig: router,
    );
  }
}