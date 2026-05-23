import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/shimmer_loading.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Customer-visible — verified-business products only. Unverified
    // sellers' products are hidden until an admin approves so a tap on
    // "View Seller" never hits permission-denied.
    final productsAsync = ref.watch(customerVisibleProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Products'),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: 'No products found',
              subtitle: 'Check back later for new products.',
            );
          }
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: () async => ref.invalidate(allActiveProductsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: products.length,
              // Canonical home-spec card. childAspectRatio bumped from
              // 0.65 → 0.62 so the taller home-card composition (image
              // + title + price + street pin) fits the grid cell
              // without overflow.
              itemBuilder: (_, i) =>
                  ProductCard(product: products[i]),
            ),
          );
        },
        loading: () => const ProductGridSkeleton(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(allActiveProductsProvider),
        ),
      ),
    );
  }
}

// _ProductGridCard removed — replaced by the canonical ProductCard
// widget (lib/widgets/product_card.dart) per the home-spec unification.
