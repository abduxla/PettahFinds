import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class EditCustomerProfileScreen extends ConsumerStatefulWidget {
  const EditCustomerProfileScreen({super.key});

  @override
  ConsumerState<EditCustomerProfileScreen> createState() =>
      _EditCustomerProfileScreenState();
}

class _EditCustomerProfileScreenState
    extends ConsumerState<EditCustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateUser(appUser.copyWith(
            displayName: _nameCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
          ));
      if (!mounted) return;
      context.showSuccessSnackBar('Profile updated');
      context.pop();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    if (appUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    if (!_initialized) {
      _nameCtrl.text = appUser.displayName;
      _phoneCtrl.text = appUser.phoneNumber ?? '';
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text('Edit Profile',
            style: GoogleFonts.nunito(
              color: AppColors.text1,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  enabled: false,
                  initialValue: appUser.email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    helperText: 'Email is managed by Firebase Auth.',
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
