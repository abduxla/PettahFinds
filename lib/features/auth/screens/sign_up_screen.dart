import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
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
      final appUser = await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text,
            role: _selectedRole,
          );
      if (!mounted) return;
      _routeAfterAuth(appUser);
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google + Apple share the same post-OAuth flow. See
  /// [_continueWithOAuth] for the full step-by-step. These wrappers
  /// only exist so the buttons read cleanly.
  Future<void> _continueWithGoogle() => _continueWithOAuth(
        () => ref.read(authRepositoryProvider).authenticateWithGoogle(),
      );

  Future<void> _continueWithApple() => _continueWithOAuth(
        () => ref.read(authRepositoryProvider).authenticateWithApple(),
      );

  /// Post-OAuth handshake.
  ///
  /// 1. Set the mid-OAuth router guard BEFORE any async work.
  /// 2. Run the platform OAuth sheet → Firebase Auth user.
  /// 3. Check /users/{uid}. Existing → route by stored role.
  /// 4. Missing → show role picker → seed /users with picked role.
  /// 5. Release the guard EXPLICITLY in every exit branch BEFORE
  ///    navigation, then route by role.
  ///
  /// No finally{} block: a finally that runs after the synchronous
  /// _routeAfterAuth call below would flip the guard off after the
  /// router has already started re-evaluating, on slow devices that
  /// produced a redirect race. Releasing per-branch keeps the
  /// suppression window exactly the danger window.
  Future<void> _continueWithOAuth(
    Future<User> Function() authenticate,
  ) async {
    debugPrint('🔵 [signup] _continueWithOAuth start');
    if (_loading) {
      debugPrint('🟡 [signup] already loading — abort');
      return;
    }
    // Keyboard down BEFORE the native sheet to stop the focused field
    // handing the keyboard off to the next screen post-OAuth.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    // CRITICAL: guard set BEFORE the first await so the router's
    // first rebuild after the Firebase Auth state change already
    // sees isHandling=true and short-circuits.
    ref.read(isHandlingSignInProvider.notifier).state = true;
    debugPrint('🔵 [signup] guard SET');

    // Tiny helper used at every successful exit branch — clears the
    // router guard AND the local _loading flag. The catch block at
    // the end calls this too so error paths can't leak the guard.
    void releaseGuards() {
      ref.read(isHandlingSignInProvider.notifier).state = false;
      if (mounted) setState(() => _loading = false);
    }

    try {
      final repo = ref.read(authRepositoryProvider);

      // ---- Step 2: OAuth ----
      debugPrint('🔵 [signup] calling authenticate()');
      final firebaseUser = await authenticate();
      debugPrint(
          '🟢 [signup] authenticate() done: uid=${firebaseUser.uid}');

      // ---- Step 3: Existing-doc check ----
      // ADAPTATION vs spec: spec uses bare `catch (_)` which would
      // re-introduce the silent-FirebaseException-swallow bug fixed
      // in commit a7657e4. We only treat the literal
      // "User document not found" sentinel as new-user; everything
      // else (permission-denied, unavailable, etc.) rethrows into
      // the outer catch which logs + signs out + shows snackbar.
      debugPrint('🔵 [signup] checking existing doc');
      AppUser? existingUser;
      try {
        existingUser = await repo.getAppUser(firebaseUser.uid);
        debugPrint(
            '🟢 [signup] existing user found: role=${existingUser.role}');
      } catch (e) {
        if (e.toString().contains('User document not found')) {
          existingUser = null;
          debugPrint('🔵 [signup] no existing doc — new user flow');
        } else {
          debugPrint(
              '🔴 [signup] getAppUser failed with REAL error — rethrowing');
          rethrow;
        }
      }

      // ---- Step 4: Existing user → skip picker ----
      if (existingUser != null) {
        debugPrint('🔵 [signup] existing user → routing by role');
        releaseGuards();
        if (!mounted) return;
        _routeAfterAuth(existingUser);
        return;
      }

      // ---- Step 5: Mounted check before picker ----
      if (!mounted) {
        debugPrint('🔴 [signup] not mounted before picker — signing out');
        await repo.signOut();
        releaseGuards();
        return;
      }

      // ---- Step 6: Role picker ----
      debugPrint('🔵 [signup] showing role picker (mounted=$mounted)');
      final role = await showSignupRolePickerSheet(
        context,
        useRootNavigator: true,
      );
      debugPrint('🔵 [signup] role picker returned: $role');

      // ---- Step 7: User cancelled picker ----
      if (role == null || role.isEmpty) {
        debugPrint('🟡 [signup] role null/empty — signing out');
        // ADAPTATION vs spec: repo.signOut() (not FirebaseAuth direct)
        // because it also clears the GoogleSignIn session so the next
        // attempt shows the account picker again instead of silently
        // re-using the last token.
        await repo.signOut();
        releaseGuards();
        return;
      }

      // ---- Step 8: Mounted check before seed ----
      if (!mounted) {
        debugPrint('🔴 [signup] not mounted before seed — signing out');
        await repo.signOut();
        releaseGuards();
        return;
      }

      // ---- Step 9: Seed the /users doc ----
      debugPrint('🔵 [signup] seeding doc with role=$role');
      final appUser = await repo.seedAppUserIfMissing(
        firebaseUser: firebaseUser,
        role: role,
      );
      debugPrint('🟢 [signup] doc seeded: role=${appUser.role}');

      // ---- Step 10: Release guard BEFORE navigating ----
      // The router redirect re-evaluates the moment the guard flips.
      // By that point appUserProvider's snapshot listener has already
      // fired (the set() succeeded synchronously above), so the
      // redirect either no-ops or routes to the same destination we
      // navigate to next.
      releaseGuards();
      debugPrint('🟢 [signup] guard RELEASED');

      if (!mounted) return;
      _routeAfterAuth(appUser);
    } catch (e, stack) {
      debugPrint('🔴 [signup] _continueWithOAuth CRASHED: $e');
      debugPrint('🔴 [signup] stack: $stack');
      // Release guard FIRST so the router can route the user back to
      // /sign-in cleanly once we sign out below.
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
    // Intentionally NO finally{} — see header comment.
  }

  /// Route directly by role using the AppUser we already have in
  /// hand from the seed/existing-doc step. The /loading screen
  /// detour was a workaround for not having the AppUser at this
  /// point; now we do.
  void _routeAfterAuth(AppUser user) {
    debugPrint(
        '🔵 [signup] _routeAfterAuth: role=${user.role} '
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
