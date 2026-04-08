import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/category.dart' as cat;
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.appName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (appUser != null)
              Text('Hello, ${appUser.displayName}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/profile/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_categoriesProvider);
          ref.invalidate(_featuredBusinessesProvider);
          ref.invalidate(_recentProductsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () => context.go('/search'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: theme.colorScheme.outline),
                      const SizedBox(width: 12),
                      Text('Search businesses & products...',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ),
            ),

            // Categories
            _SectionHeader(
              title: 'Categories',
              onSeeAll: null, // categories don't have a separate list
            ),
            categories.when(
              data: (cats) => cats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No categories yet'))
                  : SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: cats.length,
                        itemBuilder: (_, i) {
                          final c = cats[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () =>
                                  context.go('/home/category/${c.name}'),
                              child: SizedBox(
                                width: 80,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(
                                          _getCategoryIcon(c.iconName),
                                          color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(c.name,
                                        style: theme.textTheme.labelSmall,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading categories: $e')),
            ),

            const SizedBox(height: 8),

            // Featured Businesses
            _SectionHeader(
              title: 'Featured Businesses',
              onSeeAll: () => context.go('/home/businesses'),
            ),
            featured.when(
              data: (businesses) => businesses.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.store_outlined,
                      title: 'No featured businesses yet')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: businesses.length > 5 ? 5 : businesses.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (_, i) =>
                          _BusinessCard(business: businesses[i]),
                    ),
              loading: () => const SizedBox(
                  height: 120, child: LoadingWidget()),
              error: (e, _) => AppErrorWidget(message: e.toString()),
            ),

            const SizedBox(height: 8),

            // Recent Products
            _SectionHeader(
              title: 'Recent Products',
              onSeeAll: () => context.go('/home/products'),
            ),
            recentProducts.when(
              data: (products) => products.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet')
                  : SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount:
                            products.length > 10 ? 10 : products.length,
                        itemBuilder: (_, i) =>
                            _ProductCard(product: products[i]),
                      ),
                    ),
              loading: () => const SizedBox(
                  height: 210, child: LoadingWidget()),
              error: (e, _) => AppErrorWidget(message: e.toString()),
            ),
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

// --- Section header with optional "See all" ---
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

// --- Business card (vertical, used in featured list) ---
class _BusinessCard extends StatelessWidget {
  final Business business;
  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/home/business/${business.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedImage(
              imageUrl: business.bannerUrl,
              height: 130,
              width: double.infinity,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              placeholderIcon: Icons.storefront,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(business.businessName,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (business.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified,
                                  size: 16,
                                  color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${business.category} • ${business.location}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (business.ratingCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(business.ratingAvg.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium),
                      ],
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

// --- Product card (horizontal scroll, compact) ---
class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => context.go('/home/product/${product.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedImage(
                imageUrl: product.image1Url,
                height: 110,
                width: double.infinity,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                placeholderIcon: Icons.shopping_bag_outlined,
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.shortTitle.isNotEmpty
                          ? product.shortTitle
                          : product.title,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LKR ${product.priceLkr.toStringAsFixed(0)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
