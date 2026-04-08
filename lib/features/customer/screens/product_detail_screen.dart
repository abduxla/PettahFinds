import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productAsync = ref.watch(
      FutureProvider<Product>(
          (ref) => ref.read(productRepositoryProvider).getById(productId)),
    );
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return productAsync.when(
      data: (product) {
        // Load the parent business
        final businessAsync = ref.watch(
          FutureProvider<Business>((ref) => ref
              .read(businessRepositoryProvider)
              .getById(product.businessId)),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(product.title),
            actions: [
              if (appUser != null)
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    ref.read(favoriteRepositoryProvider).toggle(
                          userId: appUser.uid,
                          targetType: 'product',
                          targetId: product.id,
                        );
                    context.showSnackBar('Favorite toggled');
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image carousel
                if (product.imageUrls.isNotEmpty)
                  SizedBox(
                    height: 280,
                    child: PageView.builder(
                      itemCount: product.imageUrls.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          CachedImage(
                            imageUrl: product.imageUrls[i],
                            width: double.infinity,
                            height: 280,
                          ),
                          // Page indicator
                          if (product.imageUrls.length > 1)
                            Positioned(
                              bottom: 8,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${i + 1}/${product.imageUrls.length}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  CachedImage(
                    height: 280,
                    width: double.infinity,
                    placeholderIcon: Icons.shopping_bag,
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(product.title,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (product.shortTitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(product.shortTitle,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],

                      const SizedBox(height: 12),

                      // Price
                      Text('LKR ${product.priceLkr.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold)),

                      const SizedBox(height: 8),

                      // Category chip
                      Chip(
                        avatar: const Icon(Icons.category, size: 16),
                        label: Text(product.category),
                      ),

                      const Divider(height: 32),

                      // Description
                      Text('Description',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(product.description,
                          style: theme.textTheme.bodyMedium),

                      const Divider(height: 32),

                      // Business info card
                      Text('Sold by',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      businessAsync.when(
                        data: (business) => Card(
                          child: InkWell(
                            onTap: () => context
                                .go('/home/business/${business.id}'),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    backgroundImage:
                                        business.logoUrl.isNotEmpty
                                            ? NetworkImage(business.logoUrl)
                                            : null,
                                    child: business.logoUrl.isEmpty
                                        ? Icon(Icons.store,
                                            color: theme.colorScheme.primary)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                  business.businessName,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                            ),
                                            if (business.isVerified) ...[
                                              const SizedBox(width: 4),
                                              Icon(Icons.verified,
                                                  size: 16,
                                                  color: theme
                                                      .colorScheme.primary),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '${business.category} • ${business.location}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: theme
                                                      .colorScheme.outline),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (business.ratingCount > 0) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.star,
                                                  size: 14,
                                                  color: Colors.amber[700]),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount} reviews)',
                                                style: theme
                                                    .textTheme.labelSmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (_, _) => OutlinedButton.icon(
                          onPressed: () => context
                              .go('/home/business/${product.businessId}'),
                          icon: const Icon(Icons.store),
                          label: const Text('View Business'),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}
