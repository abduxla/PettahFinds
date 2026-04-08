import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) {
        if (user == null) {
          context.go('/onboarding');
        } else {
          final appUser = ref.read(appUserProvider).valueOrNull;
          if (appUser == null) {
            context.go('/sign-in');
          } else if (appUser.isAdmin) {
            context.go('/admin');
          } else if (appUser.isBusiness) {
            if (appUser.businessId == null || appUser.businessId!.isEmpty) {
              context.go('/business/setup');
            } else {
              context.go('/business');
            }
          } else {
            context.go('/home');
          }
        }
      },
      loading: () {},
      error: (_, __) => context.go('/sign-in'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront,
                size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppConstants.appName,
                style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(AppConstants.appTagline,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
