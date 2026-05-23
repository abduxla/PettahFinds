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

  // Google one-tap. Reuses the same role-based router shared with the
  // email path so a first-time Google user (role "user") lands on /home,
  // and a returning business owner who originally signed up via Google
  // would still hit /business if their account doc happened to have the
  // business role. We never escalate role through Google sign-in.
  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final appUser =
          await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      _routeAfterSignIn(appUser);
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Apple Sign-In is required by App Store policy whenever a third-
  /// party social sign-in is offered. Only renders the button on
  /// iOS/macOS — Android / Web fall back to email + Google.
  Future<void> _signInWithApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final appUser =
          await ref.read(authRepositoryProvider).signInWithApple();
      if (!mounted) return;
      _routeAfterSignIn(appUser);
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

  void _routeAfterSignIn(AppUser appUser) {
    if (appUser.isAdmin) {
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
