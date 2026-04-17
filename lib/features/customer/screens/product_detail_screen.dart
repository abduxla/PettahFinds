import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';

// Stable family providers — defined at top-level so retry (ref.invalidate)
// targets the same instance the UI is watching.
final _productDetailProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  if (id.isEmpty) throw Exception('Invalid product');
  final product = await ref.watch(productRepositoryProvider).getById(id);
  if (!product.isActive) {
    throw Exception('This product is no longer available');
  }
  return product;
});

final _productSellerProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, businessId) {
  if (businessId.isEmpty) throw Exception('Missing seller');
  return ref.watch(businessRepositoryProvider).getById(businessId);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Record this product as recently viewed. Fire-and-forget — best effort only.
    ref
        .read(recentlyViewedServiceProvider)
        .record(widget.productId)
        .then((_) {
      if (mounted) ref.invalidate(recentlyViewedProductsProvider);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productAsync =
        ref.watch(_productDetailProvider(widget.productId));
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return productAsync.when(
      data: (product) {
        final businessAsync =
            ref.watch(_productSellerProvider(product.businessId));

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                backgroundColor: theme.colorScheme.surface,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                actions: [
                  if (appUser != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        backgroundColor: Colors.black26,
                        child: IconButton(
                          icon: const Icon(Icons.favorite_border,
                              color: Colors.white),
                          onPressed: () {
                            ref.read(favoriteRepositoryProvider).toggle(
                                  userId: appUser.uid,
                                  targetType: 'product',
                                  targetId: product.id,
                                );
                            context.showSuccessSnackBar('Favorite toggled');
                          },
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: product.imageUrls.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              itemCount: product.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _currentImageIndex = i),
                              itemBuilder: (_, i) => CachedImage(
                                imageUrl: product.imageUrls[i],
                                width: double.infinity,
                                height: 340,
                              ),
                            ),
                            if (product.imageUrls.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    product.imageUrls.length,
                                    (i) => AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: _currentImageIndex == i ? 24 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: _currentImageIndex == i
                                            ? Colors.white
                                            : Colors.white54,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : CachedImage(
                          height: 340,
                          width: double.infinity,
                          placeholderIcon: Icons.shopping_bag,
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            product.title.isNotEmpty
                                ? product.title
                                : 'Untitled product',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                            )),
                        if (product.shortTitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(product.shortTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              )),
                        ],

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                              'LKR ${product.priceLkr.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                                letterSpacing: -0.5,
                              )),
                        ),

                        const SizedBox(height: 16),

                        if (product.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category_rounded,
                                    size: 14,
                                    color: theme.colorScheme.outline),
                                const SizedBox(width: 6),
                                Text(product.category,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    )),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        Text('Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 8),
                        Text(
                            product.description.isNotEmpty
                                ? product.description
                                : 'No description provided.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(180),
                            )),

                        const SizedBox(height: 24),
                        Divider(color: theme.dividerTheme.color),
                        const SizedBox(height: 16),

                        Text('Sold by',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 12),
                        businessAsync.when(
                          data: (business) => _SellerCard(business: business),
                          loading: () => const ShimmerBox(height: 80),
                          error: (_, _) => OutlinedButton.icon(
                            onPressed: product.businessId.isEmpty
                                ? null
                                : () => context.go(
                                    '/home/business/${product.businessId}'),
                            icon: const Icon(Icons.store),
                            label: const Text('View Business'),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_productDetailProvider(widget.productId)),
        ),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final Business business;
  const _SellerCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go('/home/business/${business.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(40), width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: business.logoUrl.isNotEmpty
                    ? NetworkImage(business.logoUrl)
                    : null,
                child: business.logoUrl.isEmpty
                    ? Icon(Icons.store,
                        color: theme.colorScheme.primary, size: 22)
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
                  if (business.ratingCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(
                          '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
