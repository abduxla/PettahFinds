import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/empty_state_widget.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  List<Business> _businesses = [];
  List<Product> _products = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // Rebuild when the query text changes so the clear button + empty
    // state reflect the live controller value.
    _searchCtrl.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  void _resetResults() {
    _searchCtrl.clear();
    setState(() {
      _businesses = [];
      _products = [];
      _searched = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onQueryChanged);
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _businesses = [];
      _products = [];
    });
    try {
      final results = await Future.wait([
        ref.read(businessRepositoryProvider).search(query),
        ref.read(productRepositoryProvider).search(query),
      ]);
      if (mounted) {
        setState(() {
          _businesses = results[0] as List<Business>;
          _products = results[1] as List<Product>;
        });
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header: back + floating search pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
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
                      child: Icon(Icons.arrow_back_rounded,
                          size: 22, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(14),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: theme.colorScheme.outline, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText:
                                    'Search businesses & products...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                                filled: false,
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty || _searched)
                            GestureDetector(
                              onTap: _resetResults,
                              child: Icon(Icons.close_rounded,
                                  color: theme.colorScheme.outline,
                                  size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.colorScheme.outline,
                  labelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Businesses (${_businesses.length})'),
                    Tab(text: 'Products (${_products.length})'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Results
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary),
                    )
                  : !_searched
                      ? const EmptyStateWidget(
                          icon: Icons.search_rounded,
                          title: 'Start searching',
                          subtitle:
                              'Find nearby businesses and products near you.',
                        )
                      : TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _businesses.isEmpty
                                ? const EmptyStateWidget(
                                    icon: Icons.store_outlined,
                                    title: 'No businesses found',
                                    subtitle:
                                        'Try a different keyword or spelling.',
                                  )
                                : ListView.builder(
                                    itemCount: _businesses.length,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 120),
                                    itemBuilder: (_, i) => _BusinessResultCard(
                                        business: _businesses[i]),
                                  ),
                            _products.isEmpty
                                ? const EmptyStateWidget(
                                    icon: Icons.shopping_bag_outlined,
                                    title: 'No products found',
                                    subtitle:
                                        'Try a different keyword or spelling.',
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 120),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.68,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                    ),
                                    itemCount: _products.length,
                                    itemBuilder: (_, i) => _ProductResultCard(
                                        product: _products[i]),
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

class _BusinessResultCard extends StatelessWidget {
  final Business business;
  const _BusinessResultCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.go('/home/business/${business.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedImage(
                imageUrl: business.bannerUrl.isNotEmpty
                    ? business.bannerUrl
                    : business.logoUrl,
                width: 72,
                height: 72,
                placeholderIcon: Icons.storefront,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                      ),
                      if (business.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified,
                            size: 15, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(business.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 13, color: theme.colorScheme.primary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(business.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSub,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                      if (business.ratingCount > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded,
                            size: 13, color: Color(0xFFE0A500)),
                        const SizedBox(width: 2),
                        Text(business.ratingAvg.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB8860B),
                              fontWeight: FontWeight.w700,
                            )),
                      ],
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

class _ProductResultCard extends StatelessWidget {
  final Product product;
  const _ProductResultCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.go('/home/product/${product.id}'),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: CachedImage(
                imageUrl: product.image1Url,
                width: double.infinity,
                placeholderIcon: Icons.shopping_bag_outlined,
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        )),
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
                    const SizedBox(height: 2),
                    Text(product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        )),
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
