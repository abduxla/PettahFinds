import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/categories.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/category.dart' as cat;
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';

/// Category docs (used to decide section order when available).
final _categoriesProvider = StreamProvider<List<cat.Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).streamActive();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(allActiveProductsProvider);
    final categoriesAsync = ref.watch(_categoriesProvider);
    final recentViewedAsync = ref.watch(recentlyViewedProductsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          ref.invalidate(allActiveProductsProvider);
          ref.invalidate(_categoriesProvider);
          ref.invalidate(recentlyViewedProductsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appUser != null
                                ? 'Hi, ${appUser.displayName.split(' ').first} 👋'
                                : 'Welcome 👋',
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Discover around you',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(14),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 22,
                        icon: Badge(
                          smallSize: 7,
                          child: Icon(Icons.notifications_none_rounded,
                              color: theme.colorScheme.onSurface),
                        ),
                        onPressed: () =>
                            context.go('/profile/notifications'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: GestureDetector(
                  onTap: () => context.go('/search'),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            color: theme.colorScheme.outline, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Search businesses & products',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withAlpha(210),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // SECTION 1 — Featured Products Carousel
            SliverToBoxAdapter(
              child: productsAsync.when(
                data: (products) {
                  final featured = _pickFeatured(products);
                  if (featured.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const _SectionHeader(title: 'Featured Products'),
                      _FeaturedCarousel(products: featured),
                    ],
                  );
                },
                loading: () => Column(
                  children: const [
                    _SectionHeader(title: 'Featured Products'),
                    _FeaturedCarouselSkeleton(),
                  ],
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(allActiveProductsProvider),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // SECTION 2 — Recently Viewed Products
            SliverToBoxAdapter(
              child: recentViewedAsync.when(
                data: (products) => Column(
                  children: [
                    _SectionHeader(
                      title: 'Recently Viewed Products',
                      actionLabel: products.isEmpty ? null : 'See all',
                      onAction: products.isEmpty
                          ? null
                          : () => context.go('/home/products'),
                    ),
                    if (products.isEmpty)
                      const _RecentlyViewedEmpty()
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: products.length,
                          itemBuilder: (_, i) =>
                              _ProductMiniCard(product: products[i]),
                        ),
                      ),
                  ],
                ),
                loading: () => Column(
                  children: const [
                    _SectionHeader(title: 'Recently Viewed Products'),
                    ProductCardSkeleton(),
                  ],
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // SECTION 3 — Products grouped by category
            productsAsync.when(
              data: (products) {
                final sections = _buildCategorySections(
                  products,
                  categoriesAsync.valueOrNull ?? const [],
                );
                if (sections.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Center(
                        child: Text(
                          'No products yet. Pull down to refresh.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _CategorySection(
                      categoryName: sections[i].name,
                      products: sections[i].products,
                    ),
                    childCount: sections.length,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Column(
                  children: const [
                    _SectionHeader(title: 'Browsing...'),
                    ProductCardSkeleton(),
                  ],
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(allActiveProductsProvider),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  /// Featured fallback logic: newest active products, max 6.
  /// (No `isFeatured` flag exists yet in Firestore — documented here so a
  /// future real flag can be layered in without rewriting the carousel.)
  static List<Product> _pickFeatured(List<Product> all) {
    if (all.isEmpty) return const [];
    final withImages =
        all.where((p) => p.image1Url.isNotEmpty).toList(growable: false);
    final source = withImages.isNotEmpty ? withImages : all;
    return source.take(6).toList();
  }

  /// Group products into category sections using the allowed list as the
  /// canonical set. Products with unrecognized / empty categories fall into
  /// 'Other' so we never explode into one-off subcategory sections. Order
  /// follows `categories` collection first (for admin-curated priority),
  /// then the remaining allowed categories in their declared order.
  static List<_CategoryBucket> _buildCategorySections(
    List<Product> products,
    List<cat.Category> categoryDocs,
  ) {
    if (products.isEmpty) return const [];
    final byCategory = <String, List<Product>>{};
    for (final p in products) {
      final key = AppCategories.normalize(p.category);
      byCategory.putIfAbsent(key, () => <Product>[]).add(p);
    }
    if (byCategory.isEmpty) return const [];

    final ordered = <_CategoryBucket>[];
    final seen = <String>{};

    // 1. Follow categories-collection order when the doc name is an allowed
    //    category and has products.
    for (final c in categoryDocs) {
      final name = AppCategories.normalize(c.name);
      if (seen.contains(name)) continue;
      final bucket = byCategory[name];
      if (bucket != null && bucket.isNotEmpty) {
        ordered.add(_CategoryBucket(name, bucket));
        seen.add(name);
      }
    }
    // 2. Fall back to the declared allowed-category order for any remaining
    //    buckets.
    for (final name in AppCategories.all) {
      if (seen.contains(name)) continue;
      final bucket = byCategory[name];
      if (bucket != null && bucket.isNotEmpty) {
        ordered.add(_CategoryBucket(name, bucket));
        seen.add(name);
      }
    }
    return ordered;
  }
}

class _CategoryBucket {
  final String name;
  final List<Product> products;
  const _CategoryBucket(this.name, this.products);
}

// ---------------- Section header ----------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
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
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: theme.colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- Featured carousel ----------------

class _FeaturedCarousel extends StatefulWidget {
  final List<Product> products;
  const _FeaturedCarousel({required this.products});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late final PageController _controller;
  int _page = 0;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _controller =
        PageController(viewportFraction: 0.88, initialPage: 0);
    if (widget.products.length > 1) {
      _auto = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.products.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.products.length,
            itemBuilder: (_, i) {
              final p = widget.products[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _FeaturedCard(product: p),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.products.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withAlpha(55),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Product product;
  const _FeaturedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.go('/home/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedImage(
              imageUrl: product.image1Url,
              width: double.infinity,
              height: double.infinity,
              placeholderIcon: Icons.shopping_bag_outlined,
            ),
            // Bottom gradient for legibility
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 130,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                  ),
                ),
              ),
            ),
            // Featured pill
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('Featured',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: -0.1,
                        )),
                  ],
                ),
              ),
            ),
            // Title + price
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.shortTitle.isNotEmpty
                        ? product.shortTitle
                        : product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'LKR ${product.priceLkr.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: theme.colorScheme.primary, size: 20),
                      ),
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

class _FeaturedCarouselSkeleton extends StatelessWidget {
  const _FeaturedCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ShimmerBox(height: 230, radius: 24),
    );
  }
}

// ---------------- Recently viewed ----------------

class _RecentlyViewedEmpty extends StatelessWidget {
  const _RecentlyViewedEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history_rounded,
                  color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing viewed yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    'Products you open will show up here.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w500,
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

// ---------------- Category section ----------------

class _CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Product> products;
  const _CategorySection({
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final preview = products.take(6).toList();
    return Column(
      children: [
        _SectionHeader(
          title: categoryName,
          actionLabel: 'See all',
          onAction: () => context.go('/home/category/$categoryName'),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: preview.length,
            itemBuilder: (_, i) =>
                _ProductMiniCard(product: preview[i]),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------- Shared mini product card ----------------

class _ProductMiniCard extends StatelessWidget {
  final Product product;
  const _ProductMiniCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 156,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
      child: InkWell(
        onTap: () => context.go('/home/product/${product.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: CachedImage(
                imageUrl: product.image1Url,
                width: double.infinity,
                placeholderIcon: Icons.shopping_bag_outlined,
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
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
                    const Spacer(),
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
            ),
          ],
        ),
      ),
    );
  }
}
