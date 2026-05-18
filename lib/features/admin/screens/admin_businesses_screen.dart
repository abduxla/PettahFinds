import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

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
        // push() so /admin/onboard stacks ON TOP of the current shell
        // tab. Using go() here triggered a shell branch switch (the
        // route used to be a sub-route of /admin in branch 0) that
        // mounted both the Dashboard and the Onboard screen during
        // the transition and collided their Form GlobalKey. The route
        // now lives at the top level; push keeps swipe-back returning
        // to the Businesses tab where the admin came from.
        onPressed: () => context.push('/manual-onboarding'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
        trailing: Switch(
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
        isThreeLine: true,
      ),
    );
  }
}
