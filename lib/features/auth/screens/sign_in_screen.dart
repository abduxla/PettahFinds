import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../utils/validators.dart';
import '../../../widgets/signup_role_picker_sheet.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final appUser = await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      _routeAfterSignIn(appUser);
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() => _continueWithOAuth(
        () => ref.read(authRepositoryProvider).authenticateWithGoogle(),
      );

  Future<void> _signInWithApple() => _continueWithOAuth(
        () => ref.read(authRepositoryProvider).authenticateWithApple(),
      );

  /// Post-OAuth handshake. Identical structure to the Sign-Up
  /// screen's _continueWithOAuth — see that file for the full
  /// step-by-step + rationale comments. The only difference here
  /// is the [debugPrint] namespace ([signin] vs [signup]) so logs
  /// from the two screens can be told apart.
  ///
  /// No finally{} block: guard is released EXPLICITLY in every exit
  /// branch BEFORE navigation fires, so on slow devices the router
  /// can never see a partially-rebuilt screen state.
  Future<void> _continueWithOAuth(
    Future<User> Function() authenticate,
  ) async {
    debugPrint('🔵 [signin] _continueWithOAuth start');
    if (_loading) {
      debugPrint('🟡 [signin] already loading — abort');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    ref.read(isHandlingSignInProvider.notifier).state = true;
    debugPrint('🔵 [signin] guard SET');

    void releaseGuards() {
      ref.read(isHandlingSignInProvider.notifier).state = false;
      if (mounted) setState(() => _loading = false);
    }

    try {
      final repo = ref.read(authRepositoryProvider);

      debugPrint('🔵 [signin] calling authenticate()');
      final firebaseUser = await authenticate();
      debugPrint(
          '🟢 [signin] authenticate() done: uid=${firebaseUser.uid}');

      // Same narrow new-user sentinel check as sign_up_screen — a bare
      // catch (_) would swallow FirebaseException and mis-route us
      // into the picker → seed → "Something went wrong" loop.
      debugPrint('🔵 [signin] checking existing doc');
      AppUser? existingUser;
      try {
        existingUser = await repo.getAppUser(firebaseUser.uid);
        debugPrint(
            '🟢 [signin] existing user found: role=${existingUser.role}');
      } catch (e) {
        if (e.toString().contains('User document not found')) {
          existingUser = null;
          debugPrint('🔵 [signin] no existing doc — new user flow');
        } else {
          debugPrint(
              '🔴 [signin] getAppUser failed with REAL error — rethrowing');
          rethrow;
        }
      }

      if (existingUser != null) {
        debugPrint('🔵 [signin] existing user → routing by role');
        releaseGuards();
        if (!mounted) return;
        _routeAfterSignIn(existingUser);
        return;
      }

      if (!mounted) {
        debugPrint('🔴 [signin] not mounted before picker — signing out');
        await repo.signOut();
        releaseGuards();
        return;
      }

      debugPrint('🔵 [signin] showing role picker (mounted=$mounted)');
      final role = await showSignupRolePickerSheet(
        context,
        useRootNavigator: true,
      );
      debugPrint('🔵 [signin] role picker returned: $role');

      if (role == null || role.isEmpty) {
        debugPrint('🟡 [signin] role null/empty — signing out');
        await repo.signOut();
        releaseGuards();
        return;
      }

      if (!mounted) {
        debugPrint('🔴 [signin] not mounted before seed — signing out');
        await repo.signOut();
        releaseGuards();
        return;
      }

      debugPrint('🔵 [signin] seeding doc with role=$role');
      final appUser = await repo.seedAppUserIfMissing(
        firebaseUser: firebaseUser,
        role: role,
      );
      debugPrint('🟢 [signin] doc seeded: role=${appUser.role}');

      releaseGuards();
      debugPrint('🟢 [signin] guard RELEASED');

      if (!mounted) return;
      _routeAfterSignIn(appUser);
    } catch (e, stack) {
      debugPrint('🔴 [signin] _continueWithOAuth CRASHED: $e');
      debugPrint('🔴 [signin] stack: $stack');
      releaseGuards();
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('cancelled')
                ? 'Sign-in cancelled.'
                : 'Sign-in failed. Please try again.',
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    // Intentionally NO finally{} — guard release is per-branch above.
  }

  /// True only on iOS/macOS where Apple's native sheet is available.
  /// Android + web hit a 401 from Apple's web flow without extra
  /// Services-ID + redirect-URL setup, which we haven't done.
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Route directly by role using the AppUser already in hand.
  /// The /loading detour is no longer needed at this call site
  /// because the new _continueWithOAuth releases the router guard
  /// BEFORE we navigate, so the redirect can either no-op or land
  /// on the same destination we're about to go to.
  void _routeAfterSignIn(AppUser user) {
    debugPrint(
        '🔵 [signin] _routeAfterSignIn: role=${user.role} '
        'businessId=${user.businessId}');
    FocusScope.of(context).unfocus();
    if (user.isAdmin) {
      context.go('/admin');
    } else if (user.isBusiness) {
      if (user.businessId == null || user.businessId!.isEmpty) {
        context.go('/business/setup');
      } else {
        context.go('/business');
      }
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- PetaFinds branded logo ----
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PetaFinds',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            color: AppColors.teal,
                            letterSpacing: -0.8,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 2),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ---- Welcome Back heading ----
                  Text('Welcome Back',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.text1,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Sign in to continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.text3,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  // ---- Form fields ----
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    validator: Validators.password,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 14),
                  // OR divider between email/password and Google.
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: AppColors.border, thickness: 1),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: GoogleFonts.dmSans(
                            color: AppColors.text3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: AppColors.border, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.account_circle_outlined, size: 20),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text1,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Apple sign-in — required by App Store Review
                  // Guidelines whenever a third-party social sign-in
                  // is offered. Only shown on iOS/macOS; Android +
                  // web fall back to email + Google. The
                  // SignInWithAppleButton enforces Apple's official
                  // styling (black pill) so the build passes App
                  // Review.
                  if (_appleAvailable) ...[
                    const SizedBox(height: 10),
                    SignInWithAppleButton(
                      onPressed:
                          _loading ? () {} : _signInWithApple,
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.circular(12),
                      height: 48,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: TextStyle(color: theme.colorScheme.outline)),
                      TextButton(
                        onPressed: () => context.go('/sign-up'),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Continue browsing as guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
