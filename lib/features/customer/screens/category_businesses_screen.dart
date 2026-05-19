import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return InkWell(
                    onTap: () => context.go('/home/product/${p.id}'),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: CachedImage(
                              imageUrl: p.image1Url,
                              width: double.infinity,
                              placeholderIcon: Icons.shopping_bag_outlined,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text1,
                                      height: 1.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'LKR ${p.priceLkr.toStringAsFixed(0)}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.teal,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const ShimmerBox(height: 220, radius: 18),
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
