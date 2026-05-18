import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';
import '../../../utils/whatsapp.dart';

/// Admin-only manual business onboarding.
///
/// Why manual at all: per-business payment setup ties revenue to the
/// owning AppUser; an automated self-signup path can race the payment
/// provisioning and produce orphaned charges. Doing this by hand keeps
/// the audit trail tight (`createdByAdminUid`) until the payment service
/// has its own onboarding webhook.
///
/// LAYOUT NOTES — this screen has been rewritten three times to escape
/// a Flutter-web render bug; the current implementation is intentionally
/// boring:
///   - No GlobalKey<FormState>. Validation is manual in [_submit]. A
///     duplicate-key crash was repeatedly hit when the screen mounted
///     near a navigator-transition boundary.
///   - No CrossAxisAlignment.stretch on the outer Column. ListView
///     children get a tight horizontal constraint by default which is
///     all we need.
///   - Action buttons live on their OWN line (full-width). The previous
///     "text field + button on the same row" layout passed unbounded
///     width into FilledButton's _InputPadding and red-screened.
///   - No decorated Container wrapping ListTile variants. Cards provide
///     the Material ancestor those tiles want.
class AdminOnboardBusinessScreen extends ConsumerStatefulWidget {
  const AdminOnboardBusinessScreen({super.key});

  /// Push this screen onto the root navigator from anywhere inside the
  /// app. Bypasses go_router so the StatefulShellRoute's branch-claim on
  /// /admin/* can never get in the way.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => const AdminOnboardBusinessScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<AdminOnboardBusinessScreen> createState() =>
      _AdminOnboardBusinessScreenState();
}

class _AdminOnboardBusinessScreenState
    extends ConsumerState<AdminOnboardBusinessScreen> {
  final _ownerEmailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _termsAcknowledged = false;
  bool _autoVerify = true;

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

  String? _validateAll() {
    if (_resolvedOwner == null) return 'Look up the merchant first.';
    if (_nameCtrl.text.trim().isEmpty) return 'Business name is required.';
    if (_categoryCtrl.text.trim().isEmpty) return 'Category is required.';
    if (_locationCtrl.text.trim().isEmpty) return 'Location is required.';
    if (_descCtrl.text.trim().isEmpty) return 'Description is required.';
    final phoneReq = Validators.required(_phoneCtrl.text, 'Phone');
    if (phoneReq != null) return phoneReq;
    final phoneFmt = Validators.phone(_phoneCtrl.text);
    if (phoneFmt != null) return phoneFmt;
    final whats = _whatsappCtrl.text.trim();
    if (whats.isNotEmpty && cleanWhatsAppNumber(whats) == null) {
      return 'WhatsApp number looks invalid.';
    }
    final emailFmt = Validators.email(_emailCtrl.text);
    if (emailFmt != null) return emailFmt;
    if (!_termsAcknowledged) {
      return 'Confirm the merchant has accepted the listing terms offline.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final err = _validateAll();
    if (err != null) {
      context.showSnackBar(err, isError: true);
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

      await ref.read(authRepositoryProvider).adminAssignBusinessToUser(
            uid: _resolvedOwner!.uid,
            businessId: created.id,
          );

      ref.invalidate(allBusinessesProvider);

      if (!mounted) return;
      context.showSuccessSnackBar(
          '${created.businessName} onboarded for ${_resolvedOwner!.displayName}');
      Navigator.of(context).pop();
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
      ),
      // ListView gives each child a tight-width constraint automatically.
      // Padding lives on the ListView so children stay flush.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ---- Header note ----
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Admin-only flow. The business is bound to the merchant\'s '
                'existing PetaFinds account. They must sign up as a regular '
                'user first.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ---- 1. Owner lookup ----
          _SectionLabel('1. Owner account'),
          const SizedBox(height: 10),
          TextField(
            controller: _ownerEmailCtrl,
            decoration: const InputDecoration(
              labelText: 'Owner email',
              prefixIcon: Icon(Icons.alternate_email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          // Button on its own line — full-width via ListView's tight
          // horizontal constraint. Never goes infinite-width.
          FilledButton.tonalIcon(
            onPressed: _lookingUp ? null : _lookupOwner,
            icon: _lookingUp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_lookingUp ? 'Looking up...' : 'Look up merchant'),
          ),
          if (_resolvedOwner != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.green.withAlpha(28),
              child: ListTile(
                leading:
                    const Icon(Icons.check_circle, color: Colors.green),
                title: Text(_resolvedOwner!.displayName),
                subtitle: Text(
                  'Role: ${_resolvedOwner!.role}'
                  '${_resolvedOwner!.businessId != null && _resolvedOwner!.businessId!.isNotEmpty ? ' • already has a business' : ''}',
                ),
                isThreeLine: false,
              ),
            ),
          ],
          const SizedBox(height: 28),

          // ---- 2. Business details ----
          _SectionLabel('2. Business details'),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Business name',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'e.g. Restaurant, Retail',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappCtrl,
            decoration: const InputDecoration(
              labelText: 'WhatsApp (optional)',
              hintText: '+94 77 123 4567',
              prefixIcon: Icon(Icons.chat_bubble_outline),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Business email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 28),

          // ---- 3. Compliance ----
          _SectionLabel('3. Compliance'),
          const SizedBox(height: 10),
          Card(
            child: CheckboxListTile(
              value: _termsAcknowledged,
              onChanged: (v) =>
                  setState(() => _termsAcknowledged = v ?? false),
              title: const Text(
                  'Merchant has accepted listing terms offline'),
              subtitle: const Text(
                  'Required for the audit trail.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: _autoVerify,
              onChanged: (v) => setState(() => _autoVerify = v),
              title: const Text('Auto-verify on creation'),
              subtitle: const Text(
                  'Skip the moderation queue. Default on for admin-onboarded merchants.'),
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
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label:
                Text(_submitting ? 'Creating...' : 'Create business'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
