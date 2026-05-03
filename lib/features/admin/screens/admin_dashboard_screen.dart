import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../widgets/loading_widget.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessesAsync = ref.watch(allBusinessesProvider);
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
      ),
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
