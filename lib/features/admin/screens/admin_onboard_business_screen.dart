import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';
import '../../../utils/whatsapp.dart';

/// Admin-only manual business onboarding.
///
/// The customer-facing /business/setup wizard self-creates a business for
/// the signed-in merchant. This screen does the inverse: a developer
/// signed in with an admin account fills in the business details on
/// behalf of a real merchant, then binds the new business doc to the
/// merchant's existing user account by email.
///
/// Why manual at all: per-business payment setup ties revenue to the
/// owning AppUser; an automated self-signup path can race the payment
/// provisioning and produce orphaned charges. Doing this by hand keeps
/// the audit trail tight (`createdByAdminUid`) until the payment service
/// has its own onboarding webhook.
class AdminOnboardBusinessScreen extends ConsumerStatefulWidget {
  const AdminOnboardBusinessScreen({super.key});

  @override
  ConsumerState<AdminOnboardBusinessScreen> createState() =>
      _AdminOnboardBusinessScreenState();
}

class _AdminOnboardBusinessScreenState
    extends ConsumerState<AdminOnboardBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerEmailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Set true once the admin has confirmed the merchant has accepted the
  // standard listing terms offline. Mirrors what /business/setup would
  // capture if the merchant signed up themselves.
  bool _termsAcknowledged = false;
  // Auto-verify the business at onboarding time. Defaults on because
  // admin-onboarded merchants have already been vetted by the dev team.
  bool _autoVerify = true;

  // Resolved owner (looked up by email). Null until lookup succeeds.
  AppUser? _resolvedOwner;
  bool _lookingUp = false;
  bool _submitting = false;

  @override
  void dispose() {
    _ownerEmailCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupOwner() async {
    final email = _ownerEmailCtrl.text.trim();
    if (email.isEmpty) {
      context.showSnackBar('Enter the merchant\'s account email first',
          isError: true);
      return;
    }
    if (Validators.email(email) != null) {
      context.showSnackBar('That doesn\'t look like a valid email',
          isError: true);
      return;
    }
    setState(() {
      _lookingUp = true;
      _resolvedOwner = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).findByEmail(email);
      if (!mounted) return;
      if (user == null) {
        context.showSnackBar(
          'No user with that email. Ask them to sign up first, then come back.',
          isError: true,
        );
      } else {
        setState(() => _resolvedOwner = user);
        // Pre-fill the business email field with the owner's email if blank.
        if (_emailCtrl.text.trim().isEmpty) {
          _emailCtrl.text = user.email;
        }
        context.showSuccessSnackBar('Owner found: ${user.displayName}');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_resolvedOwner == null) {
      context.showSnackBar(
          'Look up the owner by email before creating the business',
          isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAcknowledged) {
      context.showSnackBar(
        'Confirm the merchant has accepted the listing terms before submitting',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final adminUid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (adminUid == null) {
        throw Exception('Admin session lost — please sign in again.');
      }

      final draft = Business(
        id: '',
        businessName: _nameCtrl.text.trim(),
        ownerUid: _resolvedOwner!.uid,
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        isVerified: _autoVerify,
        createdAt: DateTime.now(),
        createdByAdminUid: adminUid,
      );

      final created =
          await ref.read(businessRepositoryProvider).create(draft);

      // Bind the business to the merchant's user doc — flips them to the
      // business role + marks onboarding complete so they land in the
      // business shell on next sign-in.
      await ref.read(authRepositoryProvider).adminAssignBusinessToUser(
            uid: _resolvedOwner!.uid,
            businessId: created.id,
          );

      // Refresh provider caches so the Businesses tab shows the new row.
      ref.invalidate(allBusinessesProvider);

      if (!mounted) return;
      context.showSuccessSnackBar(
          '${created.businessName} onboarded for ${_resolvedOwner!.displayName}');
      context.pop();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboard Business'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Always reachable via push() from admin entry points, so
          // canPop() should be true. Fallback to /admin only if some
          // future caller go()s here and replaces the stack.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(60),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            theme.colorScheme.primary.withAlpha(80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin-only flow. The business will be bound to '
                          'the merchant\'s existing PetaFinds account. '
                          'They must sign up as a regular user first.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ----- Owner lookup -----
                Text('1. Owner account',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ownerEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: FilledButton.tonal(
                        onPressed: _lookingUp ? null : _lookupOwner,
                        child: _lookingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Look up'),
                      ),
                    ),
                  ],
                ),
                if (_resolvedOwner != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_resolvedOwner!.displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                'Current role: ${_resolvedOwner!.role}'
                                '${_resolvedOwner!.businessId == null ? '' : ' • already linked to a business'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_resolvedOwner!.businessId != null &&
                      _resolvedOwner!.businessId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(28),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This user is already bound to business '
                              '${_resolvedOwner!.businessId}. Onboarding a '
                              'second will overwrite the link.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 28),
                Text('2. Business details',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => Validators.required(v, 'Business name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    hintText: 'e.g. Restaurant, Retail, Services',
                  ),
                  validator: (v) => Validators.required(v, 'Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (v) => Validators.required(v, 'Location'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  validator: (v) => Validators.required(v, 'Description'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final req = Validators.required(v, 'Phone');
                    if (req != null) return req;
                    return Validators.phone(v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _whatsappCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (optional)',
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return cleanWhatsAppNumber(t) == null
                        ? 'Enter a valid number (e.g. +94 77 123 4567)'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),

                const SizedBox(height: 24),
                Text('3. Compliance',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(60)),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _termsAcknowledged,
                        onChanged: (v) =>
                            setState(() => _termsAcknowledged = v ?? false),
                        title: const Text(
                            'Merchant has accepted listing terms offline',
                            style: TextStyle(fontSize: 13.5)),
                        subtitle: const Text(
                            'Required — keeps the audit trail clean for '
                            'payments later.',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _autoVerify,
                        onChanged: (v) => setState(() => _autoVerify = v),
                        title: const Text('Auto-verify on creation',
                            style: TextStyle(fontSize: 13.5)),
                        subtitle: const Text(
                            'Skip the moderation queue — admin-onboarded '
                            'merchants are pre-vetted.',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Create business'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
