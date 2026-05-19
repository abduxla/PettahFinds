import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import 'admin_onboard_business_screen.dart';

/// Admin moderation surface for businesses.
///
/// Three filter modes:
///   - All       — every business doc, verified or not.
///   - Pending   — unverified only (the review queue).
///   - Verified  — already-approved listings.
///
/// Pending opens by default so admins land on what needs their attention.
class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  ConsumerState<AdminBusinessesScreen> createState() =>
      _AdminBusinessesScreenState();
}

enum _Filter { pending, verified, all }

class _AdminBusinessesScreenState
    extends ConsumerState<AdminBusinessesScreen> {
  _Filter _filter = _Filter.pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Both providers are watched so switching tabs is instant — Firestore
    // listeners are already warm. Cost is one extra ongoing subscription
    // (cheap; admin sessions are short + rare).
    final allAsync = ref.watch(allBusinessesAdminProvider);
    final pendingAsync = ref.watch(pendingBusinessesProvider);

    final activeAsync = switch (_filter) {
      _Filter.all => allAsync,
      _Filter.pending => pendingAsync,
      _Filter.verified => allAsync.whenData(
          (list) => list.where((b) => b.isVerified).toList(),
        ),
    };

    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Businesses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(
                  value: _Filter.pending,
                  label: Text(pendingCount > 0
                      ? 'Pending ($pendingCount)'
                      : 'Pending'),
                  icon: const Icon(Icons.pending_actions),
                ),
                const ButtonSegment(
                  value: _Filter.verified,
                  label: Text('Verified'),
                  icon: Icon(Icons.verified_outlined),
                ),
                const ButtonSegment(
                  value: _Filter.all,
                  label: Text('All'),
                  icon: Icon(Icons.list_alt),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Bypasses go_router entirely — Navigator.push onto the root
        // navigator. Earlier attempts via go_router (sub-route + go,
        // top-level + push, renamed path + push) each hit a different
        // shell-interaction bug. Raw Navigator is the reliable path.
        onPressed: () => AdminOnboardBusinessScreen.open(context),
        icon: const Icon(Icons.add_business),
        label: const Text('Onboard'),
      ),
      body: activeAsync.when(
        data: (businesses) => businesses.isEmpty
            ? EmptyStateWidget(
                icon: _filter == _Filter.pending
                    ? Icons.inbox_outlined
                    : Icons.store_outlined,
                title: switch (_filter) {
                  _Filter.pending => 'Nothing pending review',
                  _Filter.verified => 'No verified businesses yet',
                  _Filter.all => 'No businesses',
                },
              )
            : ListView.builder(
                itemCount: businesses.length,
                // 180 px bottom: clears the bottom nav bar (~56) +
                // FloatingActionButton.extended (~56) + safe-area so the
                // last row's trash icon is reachable instead of trapped
                // under the FAB.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
                itemBuilder: (_, i) =>
                    _BusinessRow(business: businesses[i], theme: theme),
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}

class _BusinessRow extends ConsumerWidget {
  final Business business;
  final ThemeData theme;
  const _BusinessRow({required this.business, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = business;
    final isPending = !b.isVerified;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Highlight pending rows so admins can scan the queue at a glance.
      color: isPending
          ? theme.colorScheme.errorContainer.withAlpha(40)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              b.logoUrl.isNotEmpty ? NetworkImage(b.logoUrl) : null,
          child: b.logoUrl.isEmpty ? const Icon(Icons.store) : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(b.businessName)),
            if (b.isVerified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified,
                  size: 16, color: theme.colorScheme.primary),
            ],
            if (b.createdByAdminUid != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Manually onboarded by admin',
                child: Icon(Icons.admin_panel_settings,
                    size: 14,
                    color: theme.colorScheme.secondary),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${b.category} • ${b.location}\nOwner: ${b.ownerUid}',
          maxLines: 2,
        ),
        // Two trailing actions: verify toggle + destructive delete.
        // Mainaxis-min so the row never exceeds the ListTile slot.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: b.isVerified,
              onChanged: (val) async {
                try {
                  await ref
                      .read(businessRepositoryProvider)
                      .toggleVerification(b.id, val);
                  if (context.mounted) {
                    context.showSnackBar(
                      val
                          ? '${b.businessName} approved — now visible to customers'
                          : '${b.businessName} unverified — hidden from customers',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    context.showSnackBar(e.toString(), isError: true);
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Delete this account',
              icon: Icon(Icons.delete_forever_rounded,
                  color: theme.colorScheme.error),
              onPressed: () => _confirmAdminDelete(context, ref, b),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  /// Admin-side hard delete of a business + its owner's user record.
  /// Two confirmation gates:
  ///   1. AlertDialog with type-DELETE input (same as self-delete).
  ///   2. Implicit: the rule still requires isAdmin() server-side, so
  ///      even if this UI was bypassed the writes would fail unless the
  ///      caller has role == 'admin'.
  ///
  /// NOTE: the merchant's Firebase Auth identity is NOT removed (Admin
  /// SDK required). After this runs the merchant becomes a ghost — they
  /// can attempt to sign in but the app boots them on the first /users
  /// doc read.
  Future<void> _confirmAdminDelete(
      BuildContext context, WidgetRef ref, Business b) async {
    final ctrl = TextEditingController();
    var armed = false;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          ctrl.addListener(() {
            final now = ctrl.text.trim().toUpperCase() == 'DELETE';
            if (now != armed) setSt(() => armed = now);
          });
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.error),
                const SizedBox(width: 8),
                const Text('Delete this account?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'You\'re about to permanently delete the business "${b.businessName}" '
                    'and all of its products, reviews, conversations, and '
                    'the owning user\'s account data.\n\n'
                    'Note: the merchant\'s Firebase Auth identity will '
                    'remain a zombie (Admin SDK is required to remove '
                    'it). They\'ll be booted on next sign-in.'),
                const SizedBox(height: 12),
                const Text('Type DELETE to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed:
                    armed ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Delete forever'),
              ),
            ],
          );
        });
      },
    );
    if (go != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(accountDeletionServiceProvider)
          .adminDelete(b.ownerUid);
      if (context.mounted) {
        context.showSuccessSnackBar(
            '${b.businessName} and its owner account were deleted.');
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackBar(e);
    }
  }
}
