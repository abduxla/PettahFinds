import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/validators.dart';

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
    setState(() => _loading = true);
    try {
      final appUser = await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text,
            role: _selectedRole,
          );
      if (!mounted) return;
      if (appUser.isBusiness) {
        context.go('/business/setup');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/sign-in'),
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
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _loading ? null : _signUp,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign Up'),
                  ),
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
