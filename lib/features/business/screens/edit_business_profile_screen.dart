import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class EditBusinessProfileScreen extends ConsumerStatefulWidget {
  const EditBusinessProfileScreen({super.key});

  @override
  ConsumerState<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState
    extends ConsumerState<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  void _initFields(Business business) {
    if (_initialized) return;
    _nameCtrl.text = business.businessName;
    _locationCtrl.text = business.location;
    _descCtrl.text = business.description;
    _phoneCtrl.text = business.phone;
    _whatsappCtrl.text = business.whatsappNumber;
    _emailCtrl.text = business.email;
    _categoryCtrl.text = business.category;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(Business business) async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(businessRepositoryProvider).update(
            business.copyWith(
              businessName: _nameCtrl.text.trim(),
              location: _locationCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              whatsappNumber: _whatsappCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              category: _categoryCtrl.text.trim(),
            ),
          );
      // Refresh the cached business so the dashboard reflects changes
      ref.invalidate(currentUserBusinessProvider);
      if (mounted) {
        context.showSuccessSnackBar('Profile updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (business) {
        if (business == null) {
          return const Scaffold(body: Center(child: Text('No business')));
        }
        _initFields(business);

        return Scaffold(
          backgroundColor: AppColors.bgSection,
          appBar: AppBar(
            backgroundColor: AppColors.bgSection,
            title: Text('Edit Business Profile',
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
                  // ---- Avatar header ----
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.teal.withAlpha(40),
                                width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.tealLight,
                            backgroundImage: business.logoUrl.isNotEmpty
                                ? NetworkImage(business.logoUrl)
                                : null,
                            child: business.logoUrl.isEmpty
                                ? const Icon(Icons.store,
                                    size: 32, color: AppColors.teal)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.bgSection, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Form fields ----
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Business Name'),
                    validator: (v) =>
                        Validators.required(v, 'Business name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    validator: (v) => Validators.required(v, 'Category'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Location'),
                    validator: (v) => Validators.required(v, 'Location'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 4,
                    validator: (v) =>
                        Validators.required(v, 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _whatsappCtrl,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number (optional)',
                      hintText: '+94 77 123 4567',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _loading ? null : () => _save(business),
                    child: _loading
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
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}
