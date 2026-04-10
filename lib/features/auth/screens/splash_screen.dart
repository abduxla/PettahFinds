import 'dart:async';
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
  bool _navigated = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Timeout fallback: if nothing resolves in 8s, go to sign-in
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      _go('/sign-in');
    });
    // Minimum splash display time, then start checking
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _tryNavigate();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _go(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    context.go(path);
  }

  void _tryNavigate() {
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          _go('/onboarding');
          return;
        }
        // Firebase user exists — now wait for AppUser from Firestore
        _waitForAppUser();
      },
      loading: () {
        // Auth still loading — listen for changes
        _listenAuth();
      },
      error: (_, __) => _go('/sign-in'),
    );
  }

  void _listenAuth() {
    ref.listenManual(authStateProvider, (prev, next) {
      next.when(
        data: (firebaseUser) {
          if (firebaseUser == null) {
            _go('/onboarding');
          } else {
            _waitForAppUser();
          }
        },
        loading: () {},
        error: (_, __) => _go('/sign-in'),
      );
    });
  }

  void _waitForAppUser() {
    // Check if already available
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser != null) {
      _routeByRole(appUser);
      return;
    }
    // Listen for it
    ref.listenManual(appUserProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null) _routeByRole(user);
    });
  }

  void _routeByRole(dynamic appUser) {
    if (appUser.isAdmin) {
      _go('/admin');
    } else if (appUser.isBusiness) {
      if (appUser.businessId == null ||
          (appUser.businessId as String).isEmpty) {
        _go('/business/setup');
      } else {
        _go('/business');
      }
    } else {
      _go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_rounded,
                  size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(AppConstants.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: theme.colorScheme.primary,
                )),
            const SizedBox(height: 6),
            Text(AppConstants.appTagline,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
