import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

/// Splash — solid Teal-Dark field, centered "PetaFinds." wordmark
/// (Nunito 900, orange period) and tagline. Fades in on mount, fades
/// out before routing so the transition into /home feels seamless.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  Timer? _timeoutTimer;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 0,
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeController.forward();

    _timeoutTimer = Timer(const Duration(seconds: 8), () => _go('/home'));

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _tryNavigate();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _go(String path) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    await _fadeController.reverse();
    if (!mounted) return;
    context.go(path);
  }

  void _tryNavigate() {
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          _go('/home');
          return;
        }
        _waitForAppUser();
      },
      loading: _listenAuth,
      error: (_, __) => _go('/home'),
    );
  }

  void _listenAuth() {
    ref.listenManual(authStateProvider, (prev, next) {
      next.when(
        data: (firebaseUser) {
          if (firebaseUser == null) {
            _go('/home');
          } else {
            _waitForAppUser();
          }
        },
        loading: () {},
        error: (_, __) => _go('/home'),
      );
    });
  }

  void _waitForAppUser() {
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser != null) {
      _routeByRole(appUser);
      return;
    }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.tealDark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.tealDark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.tealDark,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PetaFinds',
                      style: GoogleFonts.nunito(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 2, bottom: 6),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Colombo's wholesale marketplace",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
