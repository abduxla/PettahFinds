import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_emailCtrl.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: _sent ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- PetaFinds branded logo ----
        _buildBrandLogo(),
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read,
              size: 36, color: AppColors.teal),
        ),
        const SizedBox(height: 24),
        Text('Check Your Email',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text1,
              letterSpacing: -0.4,
            )),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to ${_emailCtrl.text}',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.text3,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/sign-in'),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- PetaFinds branded logo ----
          _buildBrandLogo(),
          const SizedBox(height: 32),

          // ---- Reset Password heading ----
          Text('Reset Password',
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppColors.text1,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "Enter your email address and we'll send you a link to reset your password.",
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.text3,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ---- Email field ----
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Send Reset Link'),
          ),
          const SizedBox(height: 16),

          // ---- Back to Sign In ----
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/sign-in'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(
                'Back to Sign In',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLogo() {
    return Center(
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
    );
  }
}
