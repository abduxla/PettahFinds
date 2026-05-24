import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
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
      await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      _routeAfterSignIn();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google OAuth on the Sign-In screen.
  ///
  /// Mirrors the Sign-Up screen's [_continueWithOAuth] flow:
  ///   1. Authenticate (Firebase Auth user created)
  ///   2. Check /users/{uid}. If it exists, this is a RETURNING user
  ///      — route by their stored role, skip the picker.
  ///   3. If missing, this is a first-time Google sign-up via the
  ///      Sign-In screen (very common — users land here by default).
  ///      Show the role picker and seed /users with the chosen role.
  ///
  /// PRE-FIX BUG: previously called `signInWithGoogle()` which
  /// hardcoded `role: 'user'`, silently locking new business owners
  /// into customer accounts. There is now no code path in the app
  /// that creates a /users doc without the user explicitly picking
  /// their role.
  Future<void> _signInWithGoogle() => _continueWithOAuth(
        authenticate: () =>
            ref.read(authRepositoryProvider).authenticateWithGoogle(),
      );

  /// Apple Sign-In is required by App Store policy whenever a third-
  /// party social sign-in is offered. Only renders the button on
  /// iOS/macOS — Android / Web fall back to email + Google.
  /// Same picker-driven flow as Google (see [_continueWithOAuth]).
  Future<void> _signInWithApple() => _continueWithOAuth(
        authenticate: () =>
            ref.read(authRepositoryProvider).authenticateWithApple(),
      );

  /// Shared OAuth flow used by both Google and Apple. Identical in
  /// shape to the Sign-Up screen's `_continueWithOAuth` so both
  /// screens behave the same on first-time vs returning users — the
  /// only difference is the entry-point copy. Authentication runs,
  /// existing-doc check skips the picker for returning users, the
  /// non-dismissible role picker captures the role for new users,
  /// and a single atomic [seedAppUserIfMissing] writes the doc with
  /// the SELECTED role.
  Future<void> _continueWithOAuth({
    required Future<dynamic> Function() authenticate,
  }) async {
    if (_loading) return;
    // KEYBOARD-LINGER BUG. Before this unfocus, the email/password
    // TextFormField retained focus into the OAuth sheet round-trip;
    // when we navigated to /home the keyboard came along with the
    // focused field's restored state. Explicit unfocus here +
    // post-auth (in _routeAfterSignIn) kills the bug at both ends.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final firebaseUser = await authenticate();

      // Returning user? Use their stored role, skip the picker.
      AppUser? existing;
      try {
        existing = await repo.getAppUser(firebaseUser.uid);
      } catch (_) {
        existing = null; // doc missing — first-time OAuth
      }
      if (existing != null) {
        if (!mounted) return;
        _routeAfterSignIn();
        return;
      }

      // First-time OAuth — pick role BEFORE seeding /users/{uid}.
      if (!mounted) return;
      final pickedRole = await showSignupRolePickerSheet(context);
      if (pickedRole == null) {
        // User cancelled the (non-dismissible) sheet via the explicit
        // Cancel button — back out cleanly so we don't leave an
        // orphaned Firebase Auth session with no /users doc.
        await repo.signOut();
        return;
      }
      await repo.seedAppUserIfMissing(
        firebaseUser: firebaseUser,
        role: pickedRole,
      );
      if (!mounted) return;
      _routeAfterSignIn();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// True only on iOS/macOS where Apple's native sheet is available.
  /// Android + web hit a 401 from Apple's web flow without extra
  /// Services-ID + redirect-URL setup, which we haven't done.
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  void _routeAfterSignIn() {
    // Hand off to /loading instead of routing direct-to-role.
    //
    // Why: the AppUser stream may not have caught up to the new auth
    // state by the time we navigate, so routing direct-to-role can
    // race the router redirect and bounce the user (most painfully
    // visible for a business owner whose cached AppUser still has
    // businessId == null from a prior guest session). /loading waits
    // for the authoritative emission, then routes by role once.
    //
    // The 50ms keyboard-dismiss delay stays — it kills the linger bug
    // where the focused field handed the keyboard to the next screen.
    FocusScope.of(context).unfocus();
    Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
      if (!mounted) return;
      context.go('/loading');
    });
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
