import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'user';
  bool _loading = false;
  bool _obscure = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      context.showErrorSnackBar(
          'Please accept the User Terms of Use and Privacy Policy to continue.');
      return;
    }
    setState(() => _loading = true);
    try {
      // TODO(legal): persist accepted legal version on AppUser
      // (LegalDocuments.legalVersion + DateTime.now()) once the AppUser
      // model has acceptedTermsVersion / acceptedTermsAt fields.
      await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text,
            role: _selectedRole,
          );
      if (!mounted) return;
      _routeAfterAuth();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google + Apple share the same post-OAuth flow:
  ///   1. Run the platform sheet → Firebase Auth user.
  ///   2. Check /users/{uid}. If it exists they're a RETURNING user
  ///      who tapped sign-up by mistake — route to their role's home
  ///      and skip the picker.
  ///   3. If it doesn't exist they're a NEW user — show the role
  ///      picker bottom sheet, then seed /users with the chosen role.
  ///   4. Route based on role.
  /// Wrapped to dismiss the keyboard before AND after the OAuth call
  /// so the system keyboard doesn't linger on /home after the navigator
  /// transition (FocusManager.instance.primaryFocus?.unfocus()).
  Future<void> _continueWithGoogle() => _continueWithOAuth(
        authenticate: () =>
            ref.read(authRepositoryProvider).authenticateWithGoogle(),
      );

  Future<void> _continueWithApple() => _continueWithOAuth(
        authenticate: () =>
            ref.read(authRepositoryProvider).authenticateWithApple(),
      );

  Future<void> _continueWithOAuth({
    required Future<dynamic> Function() authenticate,
  }) async {
    if (_loading) return;
    // Dismiss the keyboard BEFORE jumping into the native OAuth sheet
    // so when the sheet returns and we navigate, there's no focused
    // field handing off the keyboard to the next screen.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    // CRITICAL: flip the mid-OAuth guard BEFORE the auth state change
    // can reach the router. Suppresses every redirect until we've
    // either written /users/{uid} with the picked role or signed the
    // user back out — closing the race where the appUserProvider's
    // post-write emission would redirect us off /sign-up mid-await
    // and abort the doc creation. Cleared in finally{}.
    ref.read(isHandlingSignInProvider.notifier).state = true;
    try {
      final repo = ref.read(authRepositoryProvider);
      final firebaseUser = await authenticate();

      // Existing user? Use their stored role + route home.
      AppUser? existing;
      try {
        existing = await repo.getAppUser(firebaseUser.uid);
      } catch (_) {
        existing = null; // doc missing — that's the new-user signal
      }
      if (existing != null) {
        if (!mounted) return;
        _routeAfterAuth();
        return;
      }

      // New user — ask for role before seeding the doc.
      if (!mounted) return;
      final pickedRole = await showSignupRolePickerSheet(context);
      if (pickedRole == null) {
        // User dismissed the sheet — abort the signup, sign back out
        // so an orphan FirebaseAuth user doesn't linger.
        await repo.signOut();
        return;
      }
      await repo.seedAppUserIfMissing(
        firebaseUser: firebaseUser,
        role: pickedRole,
      );
      if (!mounted) return;
      _routeAfterAuth();
    } catch (e) {
      // Defensive: sign back out on ANY error so we never leave a
      // Firebase Auth session alive with no /users doc (the exact
      // stranded state /loading was timing out on).
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {}
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      // Always release the router guard, even on error/cancel — the
      // router needs to be free to redirect the now-unauthed user
      // back to /sign-in.
      ref.read(isHandlingSignInProvider.notifier).state = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _routeAfterAuth() {
    // Always hand off to /loading instead of routing direct-to-role.
    //
    // Why: between the Firestore write and the appUserProvider stream
    // emitting the new doc, the router would race and bounce the user
    // (e.g. a fresh business signup with businessId still null in the
    // cached AppUser would be sent to /business/setup, then bounced
    // back, then forward — depending on stream timing). /loading is
    // listener-driven, so it waits for the authoritative emission and
    // routes once, correctly. The 50ms keyboard-dismiss delay stays.
    FocusScope.of(context).unfocus();
    Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
      if (!mounted) return;
      context.go('/loading');
    });
  }

  /// True only on iOS/macOS where Apple's native sheet is available.
  /// Web + Android need extra Services-ID setup we haven't done, so
  /// the button is hidden on those platforms.
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Pop to the screen that pushed us (typically Sign In). Fall
          // back to Sign In only when there's no stack — handles deep
          // links straight to /sign-up.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/sign-in'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
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
                  const SizedBox(height: 24),

                  // ---- Create Account heading ----
                  Text('Create Account',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.text1,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Join PetaFinds today',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.text3,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  // ---- Form fields ----
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: Validators.displayName,
                  ),
                  const SizedBox(height: 16),
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
                  ),
                  const SizedBox(height: 20),
                  Text('I am a:',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                      )),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'user',
                          label: Text('Customer'),
                          icon: Icon(Icons.person)),
                      ButtonSegment(
                          value: 'business',
                          label: Text('Business'),
                          icon: Icon(Icons.store)),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (sel) =>
                        setState(() => _selectedRole = sel.first),
                  ),
                  const SizedBox(height: 20),
                  _LegalAcceptRow(
                    accepted: _acceptedTerms,
                    onChanged: (v) =>
                        setState(() => _acceptedTerms = v ?? false),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_loading || !_acceptedTerms) ? null : _signUp,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign Up'),
                  ),

                  // ──── or divider ────
                  // Visually separates email signup from the OAuth
                  // shortcuts below. Matches the sign-in screen's
                  // divider so the two flows feel symmetric.
                  const SizedBox(height: 20),
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
                    onPressed:
                        _loading ? null : _continueWithGoogle,
                    icon: const Icon(Icons.account_circle_outlined,
                        size: 20),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text1,
                      side: const BorderSide(color: AppColors.border),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Apple sign-in — required by App Store Review when
                  // any social sign-in is offered. iOS/macOS only;
                  // Android + web fall back to email + Google.
                  if (_appleAvailable) ...[
                    const SizedBox(height: 10),
                    SignInWithAppleButton(
                      onPressed:
                          _loading ? () {} : _continueWithApple,
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.circular(12),
                      height: 48,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?',
                          style: TextStyle(color: theme.colorScheme.outline)),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Sign In'),
                      ),
                    ],
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

class _LegalAcceptRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  const _LegalAcceptRow({required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.dmSans(
      fontSize: 12.5,
      color: AppColors.text2,
      height: 1.45,
    );
    final link = GoogleFonts.dmSans(
      fontSize: 12.5,
      color: AppColors.teal,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      height: 1.45,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'User Terms of Use',
                    style: link,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.push('/legal/user-terms'),
                  ),
                  const TextSpan(text: ' and acknowledge the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: link,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.push('/legal/privacy'),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
