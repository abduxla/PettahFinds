import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final appUser = ref.read(appUserProvider).valueOrNull;
      if (appUser == null) throw Exception('Not authenticated');

      final business = await ref.read(businessRepositoryProvider).create(
            Business(
              id: '',
              businessName: _nameCtrl.text.trim(),
              ownerUid: appUser.uid,
              location: _locationCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              category: _categoryCtrl.text.trim(),
              createdAt: DateTime.now(),
            ),
          );

      // Update user with businessId
      await ref.read(authRepositoryProvider).updateUser(
            appUser.copyWith(
                businessId: business.id, onboardingCompleted: true),
          );

      if (mounted) {
        context.showSuccessSnackBar('Business created successfully!');
        context.go('/business');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text('Set Up Your Business',
            style: GoogleFonts.nunito(
              color: AppColors.text1,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
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
              const SizedBox(height: 8),
              Text(
                "Let's get your business on PetaFinds",
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ---- Form fields ----
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Business Name',
                    prefixIcon: Icon(Icons.business)),
                validator: (v) => Validators.required(v, 'Business name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    hintText: 'e.g. Restaurant, Retail, Services'),
                validator: (v) => Validators.required(v, 'Category'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on)),
                validator: (v) => Validators.required(v, 'Location'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description)),
                maxLines: 3,
                validator: (v) => Validators.required(v, 'Description'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                    labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final req = Validators.required(v, 'Phone');
                  if (req != null) return req;
                  return Validators.phone(v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Business Email',
                    prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text('Create Business'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
