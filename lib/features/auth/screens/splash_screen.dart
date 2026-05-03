import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'onboarding_screen.dart';

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
  // Cached once on init so navigation decisions don't race the prefs read.
  bool _onboardingDone = false;

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

    // Resolve the onboarding flag up front so all navigation paths
    // (timeout, fast auth, slow auth) read the same value synchronously.
    SharedPreferences.getInstance().then((prefs) {
      _onboardingDone = prefs.getBool(onboardingCompletedKey) ?? false;
    });

    // Timeout safely routes by *current* auth state; logged-in users go to
    // their role home, guests go through onboarding once. 15s is enough
    // headroom for cold Firestore reads on slow networks before we give
    // up and route by whatever we have.
    _timeoutTimer =
        Timer(const Duration(seconds: 15), _safeFallbackRoute);

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _tryNavigate();
    });
  }

  void _safeFallbackRoute() {
    if (_navigated || !mounted) return;
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _routeByRole(user);
      return;
    }
    final firebaseUser = ref.read(authStateProvider).valueOrNull;
    if (firebaseUser != null) {
      // Firebase user resolved but AppUser doc not yet — route conservatively
      // to /home so we don't strand them; router redirect will correct once
      // the AppUser stream emits.
      _go('/home');
      return;
    }
    _goGuestStart();
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

  /// Guest landing: first run goes through onboarding once, then home.
  /// Uses the value cached in [initState] to avoid racing the prefs read
  /// against the navigation timer.
  void _goGuestStart() {
    if (_navigated || !mounted) return;
    _go(_onboardingDone ? '/home' : '/onboarding');
  }

  void _tryNavigate() {
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          _goGuestStart();
          return;
        }
        _waitForAppUser();
      },
      loading: _listenAuth,
      error: (_, __) => _goGuestStart(),
    );
  }

  void _listenAuth() {
    ref.listenManual(authStateProvider, (prev, next) {
      next.when(
        data: (firebaseUser) {
          if (firebaseUser == null) {
            _goGuestStart();
          } else {
            _waitForAppUser();
          }
        },
        loading: () {},
        error: (_, __) => _goGuestStart(),
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
