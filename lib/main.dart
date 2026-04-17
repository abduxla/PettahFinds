import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'firebase_options.dart';

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

  if (_mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxAccessToken);
  }

  runApp(const ProviderScope(child: PetaFindsApp()));
}

bool get hasMapboxToken => _mapboxAccessToken.isNotEmpty;

class PetaFindsApp extends ConsumerWidget {
  const PetaFindsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}