import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

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
            body: EmptyStateWidget(
              icon: Icons.store_outlined,
              title: 'Set up your business',
              subtitle: 'Create your business profile to start selling',
              actionLabel: 'Set Up Business',
              onAction: () => context.go('/business/setup'),
            ),
          );
        }
        final business = businessDynamic as Business;
        final productsAsync =
            ref.watch(businessActiveProductsProvider(business.id));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                toolbarHeight: 70,
                title: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.colorScheme.primary.withAlpha(40),
                            width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: business.logoUrl.isNotEmpty
                            ? NetworkImage(business.logoUrl)
                            : null,
                        child: business.logoUrl.isEmpty
                            ? Icon(Icons.store,
                                color: theme.colorScheme.primary, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(business.businessName,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (business.isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified,
                                    size: 18,
                                    color: theme.colorScheme.primary),
                              ],
                            ],
                          ),
                          Text('Dashboard',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star_rounded,
                          label: 'Rating',
                          value: business.ratingCount > 0
                              ? business.ratingAvg.toStringAsFixed(1)
                              : 'N/A',
                          gradient: const [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                          iconColor: Colors.amber[700]!,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.reviews_rounded,
                          label: 'Reviews',
                          value: business.ratingCount.toString(),
                          gradient: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withAlpha(180),
                          ],
                          iconColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Tier',
                          value: business.membershipTier.toUpperCase(),
                          gradient: const [
                            Color(0xFFE8EAF6),
                            Color(0xFFC5CAE9),
                          ],
                          iconColor: const Color(0xFF5C6BC0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          )),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.add_box_rounded,
                              label: 'Add Product',
                              color: theme.colorScheme.primary,
                              onTap: () =>
                                  context.go('/business/products/add'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.inventory_2_rounded,
                              label: 'Products',
                              color: const Color(0xFF6366F1),
                              onTap: () =>
                                  context.go('/business/products'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.edit_rounded,
                              label: 'Edit Profile',
                              color: const Color(0xFF22C55E),
                              onTap: () =>
                                  context.go('/business-profile/edit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Products
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Your Products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            )),
                      ),
                      TextButton(
                        onPressed: () => context.go('/business/products'),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                ),
              ),

              productsAsync.when(
                data: (products) => products.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 48,
                                    color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                const Text('No products yet',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () =>
                                      context.go('/business/products/add'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Product'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final p = products[i];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(6),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedImage(
                                      imageUrl: p.image1Url,
                                      width: 52,
                                      height: 52,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  title: Text(p.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    'LKR ${p.priceLkr.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: p.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      p.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: p.isActive
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  onTap: () => context
                                      .go('/business/products/edit/${p.id}'),
                                ),
                              ),
                            );
                          },
                          childCount:
                              products.length > 5 ? 5 : products.length,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: ShimmerBox(height: 200),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                    child: AppErrorWidget(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(currentUserBusinessProvider),
                    )),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) => Scaffold(
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final Color iconColor;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor.withAlpha(180),
              )),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}
