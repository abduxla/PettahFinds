import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/category.dart' as cat;
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/empty_state_widget.dart';

final _categoriesProvider = StreamProvider<List<cat.Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).streamActive();
});

final _featuredBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamVerified();
});

final _recentProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).streamAll();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(_categoriesProvider);
    final featured = ref.watch(_featuredBusinessesProvider);
    final recentProducts = ref.watch(_recentProductsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          ref.invalidate(_categoriesProvider);
          ref.invalidate(_featuredBusinessesProvider);
          ref.invalidate(_recentProductsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Premium app bar
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 70,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConstants.appName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      )),
                  if (appUser != null)
                    Text('Hello, ${appUser.displayName} 👋',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Badge(
                      smallSize: 8,
                      child: Icon(Icons.notifications_outlined,
                          color: theme.colorScheme.onSurface),
                    ),
                    onPressed: () => context.go('/profile/notifications'),
                  ),
                ),
              ],
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: GestureDetector(
                  onTap: () => context.go('/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            color: theme.colorScheme.outline, size: 22),
                        const SizedBox(width: 12),
                        Text('Search businesses & products...',
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Categories
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _SectionHeader(title: 'Categories'),
                  categories.when(
                    data: (cats) => cats.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No categories yet'))
                        : SizedBox(
                            height: 104,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: cats.length,
                              itemBuilder: (_, i) {
                                final c = cats[i];
                                return GestureDetector(
                                  onTap: () =>
                                      context.go('/home/category/${c.name}'),
                                  child: Container(
                                    width: 76,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                theme.colorScheme.primaryContainer,
                                                theme.colorScheme.primaryContainer
                                                    .withAlpha(180),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                              _getCategoryIcon(c.iconName),
                                              color: theme.colorScheme.primary,
                                              size: 26),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(c.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .colorScheme.onSurface,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    loading: () => const CategorySkeleton(),
                    error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e')),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Featured Businesses
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _SectionHeader(
                    title: 'Featured Businesses',
                    actionLabel: 'See all',
                    onAction: () => context.go('/home/businesses'),
                  ),
                  featured.when(
                    data: (businesses) => businesses.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.store_outlined,
                            title: 'No featured businesses yet')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                businesses.length > 5 ? 5 : businesses.length,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemBuilder: (_, i) =>
                                _BusinessCard(business: businesses[i]),
                          ),
                    loading: () => const BusinessCardSkeleton(count: 2),
                    error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e')),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Recent Products
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _SectionHeader(
                    title: 'Recent Products',
                    actionLabel: 'See all',
                    onAction: () => context.go('/home/products'),
                  ),
                  recentProducts.when(
                    data: (products) => products.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products yet')
                        : SizedBox(
                            height: 230,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: products.length > 10
                                  ? 10
                                  : products.length,
                              itemBuilder: (_, i) =>
                                  _ProductCard(product: products[i]),
                            ),
                          ),
                    loading: () => const ProductCardSkeleton(),
                    error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e')),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'shopping':
      case 'retail':
        return Icons.shopping_bag;
      case 'health':
      case 'medical':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'electronics':
        return Icons.devices;
      case 'beauty':
        return Icons.spa;
      case 'automotive':
        return Icons.directions_car;
      case 'services':
        return Icons.build;
      default:
        return Icons.category;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: theme.colorScheme.onSurface,
                )),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 12,
                      color: theme.colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Business business;
  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/home/business/${business.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedImage(
              imageUrl: business.bannerUrl,
              height: 140,
              width: double.infinity,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              placeholderIcon: Icons.storefront,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(40),
                          width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: business.logoUrl.isNotEmpty
                          ? NetworkImage(business.logoUrl)
                          : null,
                      child: business.logoUrl.isEmpty
                          ? Icon(Icons.store,
                              color: theme.colorScheme.primary, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(business.businessName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (business.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified,
                                  size: 16, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${business.category} • ${business.location}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (business.ratingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(business.ratingAvg.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[800],
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/home/product/${product.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedImage(
              imageUrl: product.image1Url,
              height: 140,
              width: double.infinity,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              placeholderIcon: Icons.shopping_bag_outlined,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.shortTitle.isNotEmpty
                        ? product.shortTitle
                        : product.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'LKR ${product.priceLkr.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
