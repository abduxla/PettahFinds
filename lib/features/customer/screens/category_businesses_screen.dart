import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/shimmer_loading.dart';

/// Category landing — renders PRODUCTS in the given category (per the
/// app convention "search is products, map is businesses"). Class name
/// is kept for git/route compatibility; the route is `/home/category/:x`.
class CategoryBusinessesScreen extends ConsumerWidget {
  final String categoryName;
  const CategoryBusinessesScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Customer-visible — drops products from unverified businesses so
    // the "View Seller" tap never breaks.
    final productsAsync =
        ref.watch(customerVisibleProductsByCategoryProvider(categoryName));

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          categoryName,
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.shopping_bag_outlined,
                title: 'No products found',
                subtitle:
                    'No products listed in this category yet. Check back soon.',
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                // mainAxisExtent locks the cell height to the canonical
                // ProductCard's natural content height — eliminates the
                // bottom-of-cell whitespace the old childAspectRatio:0.68
                // produced. 218 = 108 image + ~110 content/padding stack
                // measured against ProductCard's spec.
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 218,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: products.length,
                // Use the canonical ProductCard — the prior custom card
                // (Expanded flex 3/2 with Spacer) reflowed unpredictably
                // and left empty space below the price on tall cells.
                itemBuilder: (_, i) => ProductCard(product: products[i]),
              ),
        loading: () => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 218,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const ShimmerBox(height: 218, radius: 18),
        ),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(productsByCategoryProvider(categoryName)),
        ),
      ),
    );
  }
}
