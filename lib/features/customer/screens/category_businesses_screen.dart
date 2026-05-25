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
                // Larger cells to match the Temu / Daraz reference. The
                // canonical ProductCard takes imageHeight=140 here (vs.
                // 108 on home's "for you" rail) so the photo dominates
                // the card like the reference. mainAxisExtent=250 leaves
                // ~7px of slack below the address pin so it never gets
                // clipped on dense font metrics.
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 250,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(
                  product: products[i],
                  imageHeight: 140,
                ),
              ),
        loading: () => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 250,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const ShimmerBox(height: 250, radius: 18),
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
