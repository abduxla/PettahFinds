import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';

/// Post-auth landing pad. Renders a centered teal spinner while it
/// waits for `appUserProvider` to emit a non-null [AppUser], then
/// hands off to the role-correct home.
///
/// Why it exists: between Firebase Auth resolving and the
/// `/users/{uid}` Firestore doc being readable (or written for the
/// first time on OAuth signup), there is a window where the router
/// would see `isLoggedIn == true` but `appUser == null`. The old code
/// short-circuited the redirect during that window, which let users
/// land on shells whose screens watched `appUserProvider` and showed
/// a permanent CircularProgressIndicator with no sign-out escape.
///
/// This screen replaces that window with a deliberate gate: a
/// listener-driven router that always exits, and a 10s timeout that
/// surfaces an emergency Sign Out & Retry if the doc never arrives
/// (network failure, missing user doc, etc.). No more dead-end loops.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  Timer? _timeout;
  Timer? _slowTick;
  bool _navigated = false;
  bool _stuck = false;
  // Flips at the halfway mark so the spinner copy reassures users that
  // we're still working on slow connections instead of looking frozen.
  bool _showSlowMessage = false;
  // Counts non-routing emissions from appUserProvider so we can probe
  // Firestore directly after a few empty hits and surface the REAL
  // error (e.g. permission-denied) instead of the generic "Something
  // went wrong" copy.
  int _emptyEmissions = 0;
  String? _firebaseDiagnostic;

  // 20s total — generous enough to cover slow upstream Firestore
  // writes + first-read replication on weak Sri Lankan mobile data.
  // The 10s mark switches the copy from "Setting up your account..."
  // to "Almost there..." so the screen doesn't feel dead.
  static const _timeoutDuration = Duration(seconds: 20);
  static const _slowMessageAfter = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _armTimeout();
    // First-frame check covers the "data already present" case (e.g.
    // existing user signing in — the AppUser stream may already have a
    // cached value from a previous session).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryRouteFromCurrentState();
    });
  }

  void _armTimeout() {
    _timeout?.cancel();
    _slowTick?.cancel();
    _showSlowMessage = false;
    _slowTick = Timer(_slowMessageAfter, () {
      if (mounted && !_navigated) setState(() => _showSlowMessage = true);
    });
    _timeout = Timer(_timeoutDuration, () {
      if (mounted && !_navigated) setState(() => _stuck = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _slowTick?.cancel();
    super.dispose();
  }

  void _tryRouteFromCurrentState() {
    final authUser = ref.read(authStateProvider).valueOrNull;
    debugPrint(
        '⏳ [loading] tryRouteFromCurrentState: authUid=${authUser?.uid}');
    // No Firebase Auth user at all — bail to sign-in immediately.
    // Defensive: the router redirect should have caught this, but if a
    // caller deep-links straight to /loading we must not strand them.
    if (authUser == null) {
      debugPrint('🔴 [loading] no Firebase Auth user → /sign-in');
      _go('/sign-in');
      return;
    }
    final appUser = ref.read(appUserProvider).valueOrNull;
    debugPrint(
        '⏳ [loading] initial appUser snapshot: role=${appUser?.role} '
        'businessId=${appUser?.businessId}');
    if (appUser != null) _routeByRole(appUser);
  }

  void _routeByRole(AppUser u) {
    debugPrint(
        '🟢 [loading] routeByRole: role=${u.role} businessId=${u.businessId}');
    if (u.isAdmin) {
      _go('/admin');
      return;
    }
    if (u.isBusiness) {
      if (u.businessId == null || u.businessId!.isEmpty) {
        _go('/business/setup');
      } else {
        _go('/business');
      }
      return;
    }
    _go('/home');
  }

  void _go(String path) {
    if (_navigated || !mounted) {
      debugPrint(
          '⏳ [loading] _go($path) ignored — navigated=$_navigated mounted=$mounted');
      return;
    }
    debugPrint('🟢 [loading] _go($path) firing');
    _navigated = true;
    _timeout?.cancel();
    context.go(path);
  }

  Future<void> _emergencySignOut() async {
    // Don't show a snackbar on failure — by definition we're in a
    // recovery flow and the user just wants out. Sign-out is best-
    // effort; the route to /sign-in will fire regardless.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    // Force-clear any cached Riverpod state tied to the stranded
    // session so the next sign-in starts from a clean slate. Without
    // these invalidates, a stale AppUser snapshot could otherwise
    // race the new auth state and re-route the user back into the
    // broken state they just escaped.
    ref.invalidate(appUserProvider);
    ref.invalidate(currentUserBusinessProvider);
    // Also release the mid-OAuth guard in case the stuck state
    // happened mid-handshake (defensive — the OAuth caller's
    // finally{} already clears it on the happy path).
    ref.read(isHandlingSignInProvider.notifier).state = false;
    if (!mounted) return;
    _navigated = false; // allow _go to fire
    _go('/sign-in');
  }

  void _retry() {
    setState(() {
      _stuck = false;
      _firebaseDiagnostic = null;
      _emptyEmissions = 0;
    });
    _armTimeout();
    _tryRouteFromCurrentState();
  }

  /// One-shot direct read against /users/{uid} that bypasses the
  /// Riverpod stream, so the FirebaseException code (if any) lands
  /// in our hands instead of being mapped to null by the stream's
  /// `.map((doc) => doc.exists ? ... : null)`. Result is rendered
  /// on the stuck recovery card so a non-developer can still
  /// screenshot the actual error.
  Future<void> _probeFirestoreForError() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      final data = doc.data();
      debugPrint(
          '🔴 [loading] probe: exists=${doc.exists} data=$data');
      if (mounted) {
        setState(() {
          _firebaseDiagnostic = doc.exists
              ? 'Doc exists but role missing.\nuid=$uid\ndata=$data'
              : 'Firestore says /users/$uid does NOT exist '
                  'after sign-in. The picker→seed write never landed.';
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('🔴 [loading] probe FIREBASE ERROR');
      debugPrint('🔴   code=${e.code}');
      debugPrint('🔴   message=${e.message}');
      debugPrint('🔴   plugin=${e.plugin}');
      if (mounted) {
        setState(() {
          _firebaseDiagnostic = 'FirebaseException\n'
              'code: ${e.code}\n'
              'plugin: ${e.plugin}\n'
              'message: ${e.message}';
        });
      }
    } catch (e, st) {
      debugPrint('🔴 [loading] probe UNKNOWN ERROR: $e');
      debugPrint('🔴 stack: $st');
      if (mounted) {
        setState(() {
          _firebaseDiagnostic = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Two listeners — together they cover every way out:
    //   1. appUserProvider emits a real AppUser  → route by role.
    //   2. authStateProvider drops to null       → bail to /sign-in.
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (prev, next) {
      final u = next.valueOrNull;
      debugPrint(
          '⏳ [loading] appUserProvider emit: role=${u?.role} '
          'isLoading=${next.isLoading} hasError=${next.hasError}');
      if (u != null) {
        _routeByRole(u);
        return;
      }
      // Empty / null emission while signed in — count it. After
      // 3 consecutive empties we probe Firestore directly to
      // capture the REAL error (permission-denied, unavailable,
      // etc.) and surface its code on the recovery card instead
      // of the generic "Something went wrong".
      _emptyEmissions += 1;
      if (_emptyEmissions == 3) {
        debugPrint(
            '🔴 [loading] 3 empty appUser emissions — probing Firestore directly');
        _probeFirestoreForError();
      }
    });
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      debugPrint(
          '⏳ [loading] authStateProvider emit: uid=${next.valueOrNull?.uid}');
      if (!next.isLoading && next.valueOrNull == null) _go('/sign-in');
    });

    if (_stuck) return _buildStuckRecovery();
    return _buildSpinner();
  }

  Widget _buildSpinner() {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.teal),
              const SizedBox(height: 16),
              Text(
                _showSlowMessage
                    ? 'Almost there...'
                    : 'Setting up your account...',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: AppColors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStuckRecovery() {
    final diagnostic = _firebaseDiagnostic;
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_tethering_error_rounded,
                  color: AppColors.text4,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We couldn't finish loading your account. Check your "
                  'connection and try again — or sign out and start fresh.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.text3,
                    height: 1.45,
                  ),
                ),
                if (diagnostic != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      diagnostic,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.firaMono(
                        fontSize: 11.5,
                        color: AppColors.text1,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _emergencySignOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out & Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                    ),
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
