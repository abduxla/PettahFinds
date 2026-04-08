import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (businessDynamic) {
        if (businessDynamic == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No business found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/business/setup'),
                    child: const Text('Set Up Business'),
                  ),
                ],
              ),
            ),
          );
        }
        final business = businessDynamic as Business;
        final productsAsync = ref.watch(
          StreamProvider<List<Product>>((ref) => ref
              .read(productRepositoryProvider)
              .streamByBusiness(business.id)),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(business.businessName),
            actions: [
              if (business.isVerified)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.verified,
                      color: theme.colorScheme.primary),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.star,
                      label: 'Rating',
                      value: business.ratingCount > 0
                          ? business.ratingAvg.toStringAsFixed(1)
                          : 'N/A',
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.reviews,
                      label: 'Reviews',
                      value: business.ratingCount.toString(),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.workspace_premium,
                      label: 'Tier',
                      value: business.membershipTier.toUpperCase(),
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick actions
              Text('Quick Actions',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionChip(
                    icon: Icons.add_box,
                    label: 'Add Product',
                    onTap: () => context.go('/business/products/add'),
                  ),
                  _ActionChip(
                    icon: Icons.inventory,
                    label: 'Manage Products',
                    onTap: () => context.go('/business/products'),
                  ),
                  _ActionChip(
                    icon: Icons.edit,
                    label: 'Edit Profile',
                    onTap: () => context.go('/business-profile/edit'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent products
              Text('Your Products',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              productsAsync.when(
                data: (products) => products.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48,
                                  color: theme.colorScheme.outline),
                              const SizedBox(height: 8),
                              const Text('No products yet'),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () =>
                                    context.go('/business/products/add'),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Product'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: products
                            .take(5)
                            .map((p) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(p.title),
                                    subtitle: Text(
                                        'LKR ${p.priceLkr.toStringAsFixed(2)}'),
                                    trailing: Text(p.isActive
                                        ? 'Active'
                                        : 'Inactive'),
                                    onTap: () => context.go(
                                        '/business/products/edit/${p.id}'),
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const LoadingWidget(),
                error: (e, _) => AppErrorWidget(message: e.toString()),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
