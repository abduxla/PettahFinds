import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';
import '../../../utils/whatsapp.dart';

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
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;
  bool _acceptedUserTerms = false;
  bool _acceptedListingAgreement = false;
  bool _acceptedProhibitedPolicy = false;

  bool get _allLegalAccepted =>
      _acceptedUserTerms &&
      _acceptedListingAgreement &&
      _acceptedProhibitedPolicy;

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

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_allLegalAccepted) {
      context.showErrorSnackBar(
          'Please accept all required legal documents to continue.');
      return;
    }
    setState(() => _loading = true);
    // TODO(legal): persist accepted legal version on the Business or AppUser
    // (LegalDocuments.legalVersion + DateTime.now()) once the model has
    // acceptedTermsVersion / acceptedTermsAt fields.
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
              whatsappNumber: _whatsappCtrl.text.trim(),
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

      // Refresh the cached business so the dashboard sees the new doc.
      ref.invalidate(currentUserBusinessProvider);

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
                controller: _whatsappCtrl,
                decoration: const InputDecoration(
                    labelText: 'WhatsApp Number (optional)',
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.chat_bubble_outline)),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return cleanWhatsAppNumber(t) == null
                      ? 'Enter a valid number (e.g. +94 77 123 4567)'
                      : null;
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
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _LegalCheckRow(
                      accepted: _acceptedUserTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedUserTerms = v ?? false),
                      spans: [
                        const _LegalSpan('I agree to the '),
                        _LegalSpan('User Terms of Use',
                            href: '/legal/user-terms'),
                        const _LegalSpan(' and acknowledge the '),
                        _LegalSpan('Privacy Policy',
                            href: '/legal/privacy'),
                        const _LegalSpan('.'),
                      ],
                    ),
                    _LegalCheckRow(
                      accepted: _acceptedListingAgreement,
                      onChanged: (v) => setState(
                          () => _acceptedListingAgreement = v ?? false),
                      spans: [
                        const _LegalSpan('I agree to the '),
                        _LegalSpan('Business Listing Agreement',
                            href: '/legal/business-listing-agreement'),
                        const _LegalSpan('.'),
                      ],
                    ),
                    _LegalCheckRow(
                      accepted: _acceptedProhibitedPolicy,
                      onChanged: (v) => setState(
                          () => _acceptedProhibitedPolicy = v ?? false),
                      spans: [
                        const _LegalSpan('I agree to the '),
                        _LegalSpan('Content and Prohibited Listings Policy',
                            href: '/legal/prohibited-listings'),
                        const _LegalSpan('.'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_loading || !_allLegalAccepted) ? null : _submit,
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

class _LegalSpan {
  final String text;
  final String? href;
  const _LegalSpan(this.text, {this.href});
}

class _LegalCheckRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final List<_LegalSpan> spans;
  const _LegalCheckRow({
    required this.accepted,
    required this.onChanged,
    required this.spans,
  });

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
                  for (final s in spans)
                    if (s.href != null)
                      TextSpan(
                        text: s.text,
                        style: link,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push(s.href!),
                      )
                    else
                      TextSpan(text: s.text),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
