import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../widgets/loading_widget.dart';
import 'admin_onboard_business_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Admin counts pull from the unfiltered admin stream so they
    // include pending + verified together (otherwise the totals would
    // exclude the very rows that need attention).
    final businessesAsync = ref.watch(allBusinessesAdminProvider);
    final pendingAsync = ref.watch(pendingBusinessesProvider);
    final productsAsync = ref.watch(allActiveProductsProvider);
    final reportsAsync = ref.watch(allReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/sign-in');
            },
          ),
        ],
      ),
      body: Builder(builder: (context) {
        // Pre-compute the pending count so the children list can use a
        // collection-if. Returning different widget types from
        // pendingAsync.maybeWhen at the same ListView slot was confusing
        // Flutter's element diff and triggering `_elements.contains` —
        // a fully-omitted-vs-fully-present slot avoids the swap entirely.
        final pendingCount = pendingAsync.valueOrNull?.length ?? 0;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.go('/admin/businesses'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.pending_actions,
                              color: theme.colorScheme.onErrorContainer,
                              size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$pendingCount business${pendingCount == 1 ? '' : 'es'} awaiting review',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: theme.colorScheme.onErrorContainer),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Quick action card — manual onboarding is the highest-leverage
          // admin task right now (until payments has its own webhook), so
          // it earns the top slot above the metrics.
          Card(
            color: theme.colorScheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              // Navigator.push on the root navigator — see note in
              // admin_businesses_screen FAB.
              onTap: () => AdminOnboardBusinessScreen.open(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.add_business,
                        size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onboard a new business',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            'Manually create a listing on behalf of a '
                            'merchant. Keeps payment records clean.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Overview',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DashCard(
                  icon: Icons.store,
                  label: 'Businesses',
                  value: businessesAsync.when(
                    data: (b) => b.length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'err',
                  ),
                  color: theme.colorScheme.primary,
                  onTap: () => context.go('/admin/businesses'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashCard(
                  icon: Icons.inventory,
                  label: 'Products',
                  value: productsAsync.when(
                    data: (p) => p.length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'err',
                  ),
                  color: theme.colorScheme.secondary,
                  onTap: () => context.go('/admin/products'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DashCard(
                  icon: Icons.flag,
                  label: 'Reports',
                  value: reportsAsync.when(
                    data: (r) => r.length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'err',
                  ),
                  color: theme.colorScheme.error,
                  onTap: () => context.go('/admin/reports'),
                ),
              ),
              Expanded(
                child: _DashCard(
                  icon: Icons.verified,
                  label: 'Verified',
                  value: businessesAsync.when(
                    data: (b) =>
                        b.where((x) => x.isVerified).length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'err',
                  ),
                  color: Colors.green,
                  onTap: () => context.go('/admin/businesses'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Reports',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          reportsAsync.when(
            data: (reports) {
              final recent = reports.take(5).toList();
              if (recent.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No reports'),
                  ),
                );
              }
              return Column(
                children: recent
                    .map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(Icons.flag,
                                color: r.status == 'pending'
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline),
                            title: Text(r.reason, maxLines: 1),
                            subtitle: Text(r.status.toUpperCase()),
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
        );
      }),
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _DashCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
