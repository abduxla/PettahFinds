import 'dart:async';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/categories.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/sign_in_required.dart';

// ---------- Real-data providers ----------
final _homeBusinessByIdProvider =
    FutureProvider.autoDispose.family<Business?, String>((ref, id) async {
  if (id.isEmpty) return null;
  try {
    return await ref.watch(businessRepositoryProvider).getById(id);
  } catch (_) {
    return null;
  }
});

/// Streamed set of `productId`s currently favorited by the signed-in user.
/// Used by product-card hearts to render true saved state and to toggle.
final _favoriteProductIdsProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, uid) {
  return ref
      .watch(favoriteRepositoryProvider)
      .streamByUser(uid)
      .map((list) => list
          .where((f) => f.targetType == 'product')
          .map((f) => f.targetId)
          .toSet());
});

// ---------- Category visual style ----------
class _CategoryStyle {
  final String emoji;
  final Color badgeBg;
  final String streetSub;
  const _CategoryStyle(this.emoji, this.badgeBg, this.streetSub);
}

const Map<String, _CategoryStyle> _catStyles = {
  'Electronics':        _CategoryStyle('📱', Color(0xFFEEF2FF), '1st Cross St. · Front St.'),
  'Clothing':           _CategoryStyle('👗', Color(0xFFFFF0F7), '4th Cross St. · 1st Cross St.'),
  'Grocery':            _CategoryStyle('🛒', Color(0xFFFEF3E8), '3rd Cross St. · Sea Street'),
  'Food & Drink':       _CategoryStyle('🍽️', Color(0xFFFFF8F0), '3rd Cross St. · Front St.'),
  'Spices':             _CategoryStyle('🌶️', Color(0xFFFFF0F0), '4th Cross St. · 3rd Cross St.'),
  'Jewellery':          _CategoryStyle('💎', Color(0xFFFFFBEB), 'Sea Street · Keyzer St.'),
  'Home & Living':      _CategoryStyle('🏠', Color(0xFFF0F8FF), 'Main St. · 2nd Cross St.'),
  'Beauty & Wellness':  _CategoryStyle('💄', Color(0xFFFFF0F7), 'Bankshall St. · Front St.'),
  'Services':           _CategoryStyle('🛠️', Color(0xFFE8F4F4), 'Pettah'),
  'Sports & Outdoors':  _CategoryStyle('⚽', Color(0xFFF0FFF4), 'Main St.'),
  'Stationery & Books': _CategoryStyle('📚', Color(0xFFF5F3FF), '2nd Cross St.'),
  'Toys & Kids':        _CategoryStyle('🧸', Color(0xFFFFF0F0), 'Keyzer St.'),
  'Other':              _CategoryStyle('🛍️', Color(0xFFF2F2EF), 'Pettah'),
};

_CategoryStyle _styleFor(String raw) =>
    _catStyles[AppCategories.normalize(raw)] ?? _catStyles['Other']!;

// Per-product tile backgrounds — cycle through warm tints per category.
const List<Color> _tileTints = [
  Color(0xFFFEF3E8),
  Color(0xFFE8F4F4),
  Color(0xFFF0F0FF),
  Color(0xFFFFF8F0),
  Color(0xFFFFFBEB),
  Color(0xFFF0FFF4),
];

// =========================================================================
// HOME SCREEN
// =========================================================================
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allActiveProductsProvider);
    final recentAsync = ref.watch(recentlyViewedProductsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.tealDark,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgSection,
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              ref.invalidate(allActiveProductsProvider);
              ref.invalidate(recentlyViewedProductsProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ---- Header ----
                const SliverToBoxAdapter(child: _TealHeader()),

                // ---- Featured Carousel (white section) ----
                const SliverToBoxAdapter(child: _FeaturedSection()),

                // ---- Recently Viewed (white section) ----
                SliverToBoxAdapter(
                  child: recentAsync.when(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : _RecentlyViewedSection(products: items),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                // ---- Category Sections ----
                productsAsync.when(
                  data: (products) {
                    final sections = _buildCategorySections(products);
                    if (sections.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _EmptyProductsState(),
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
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppErrorWidget(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(allActiveProductsProvider),
                      ),
                    ),
                  ),
                ),

                // Bottom spacer above nav.
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Preferred category order from the spec.
  static const List<String> _preferredOrder = [
    'Electronics',
    'Clothing',
    'Grocery',
    'Spices',
    'Jewellery',
    'Food & Drink',
    'Home & Living',
    'Beauty & Wellness',
    'Services',
    'Sports & Outdoors',
    'Stationery & Books',
    'Toys & Kids',
    'Other',
  ];

  static List<_CategoryBucket> _buildCategorySections(List<Product> products) {
    if (products.isEmpty) return const [];
    final byCategory = <String, List<Product>>{};
    for (final p in products) {
      final key = AppCategories.normalize(p.category);
      byCategory.putIfAbsent(key, () => <Product>[]).add(p);
    }
    final ordered = <_CategoryBucket>[];
    for (final name in _preferredOrder) {
      final bucket = byCategory[name];
      if (bucket != null && bucket.isNotEmpty) {
        ordered.add(_CategoryBucket(name, bucket));
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

// =========================================================================
// TEAL HEADER — logo · tagline · heart · bell · search bar
// =========================================================================
class _TealHeader extends ConsumerWidget {
  const _TealHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.of(context).padding.top;
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;
    return Container(
      color: AppColors.tealDark,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: logo stack
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PetaFinds',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Colombo's wholesale marketplace",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              // Right: heart + bell
              Row(
                children: [
                  _HeaderIconButton(
                    icon: Icons.favorite_border,
                    onTap: () {
                      if (isGuest) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        showSignInRequiredSheet(context);
                      } else {
                        context.go('/favorites');
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {
                      if (isGuest) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        showSignInRequiredSheet(context);
                      } else {
                        context.go('/profile/notifications');
                      }
                    },
                    badgeCount: 3,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.go('/search'),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      color: AppColors.text4, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search businesses & products…',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.text4,
                      ),
                    ),
                  ),
                  const Icon(Icons.tune,
                      color: AppColors.text4, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (badgeCount != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.tealDark, width: 1.5),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: GoogleFonts.dmSans(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// FEATURED CAROUSEL — 3 static slides with gradients, orbs, floating emoji
// =========================================================================
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: const _FeaturedCarousel(),
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel();

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _autoTimer;
  Timer? _clockTimer;
  late final AnimationController _floatController;
  Duration _countdown = const Duration(hours: 8);

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _autoTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % 3;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });

    _updateCountdown();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final eod = DateTime(now.year, now.month, now.day, 23, 59, 59);
    setState(() {
      _countdown = eod.difference(now);
      if (_countdown.isNegative) _countdown = Duration.zero;
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _clockTimer?.cancel();
    _floatController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<_SlideData> get _slides => [
        _SlideData(
          eyebrow: 'TODAY ONLY',
          title: 'Up to 40%\nOFF Spices',
          sub: '4th Cross Street · Bulk wholesale',
          cta: 'Browse deals',
          emoji: '🌶️',
          tagText: 'Flash Sale · ${_fmt(_countdown)}',
          dotColor: const Color(0xFF6EE7B7),
          gradient: const [
            Color(0xFF0A4A4A),
            Color(0xFF0D6E6E),
            Color(0xFF1A9696),
          ],
        ),
        const _SlideData(
          eyebrow: 'SEA STREET',
          title: 'Gold &\nJewellery',
          sub: '200+ verified jewellers listed',
          cta: 'Explore now',
          emoji: '💎',
          tagText: 'New Arrivals',
          dotColor: Color(0xFFFBBF24),
          gradient: [
            Color(0xFF6B2D00),
            Color(0xFFC25A00),
            Color(0xFFE8821A),
          ],
        ),
        const _SlideData(
          eyebrow: '4TH CROSS STREET',
          title: 'Textiles &\nFabrics',
          sub: 'Wholesale fabric from LKR 500/m',
          cta: 'See listings',
          emoji: '🧵',
          tagText: 'Featured',
          dotColor: Color(0xFF93C5FD),
          gradient: [
            Color(0xFF1A2C5E),
            Color(0xFF2D4A9A),
            Color(0xFF4A6CC8),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FeaturedSlide(
                data: slides[i],
                floatController: _floatController,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = _page == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 14,
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.teal : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _SlideData {
  final String eyebrow;
  final String title;
  final String sub;
  final String cta;
  final String emoji;
  final String tagText;
  final Color dotColor;
  final List<Color> gradient;
  const _SlideData({
    required this.eyebrow,
    required this.title,
    required this.sub,
    required this.cta,
    required this.emoji,
    required this.tagText,
    required this.dotColor,
    required this.gradient,
  });
}

class _FeaturedSlide extends StatelessWidget {
  final _SlideData data;
  final AnimationController floatController;
  const _FeaturedSlide({
    required this.data,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — gradient
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.55, 1.0],
                colors: data.gradient,
              ),
            ),
          ),
          // Layer 2 — orb 1
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Layer 3 — orb 2
          Positioned(
            bottom: -40,
            right: 60,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Layer 4 — tag badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: data.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    data.tagText,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Layer 5 — floating emoji
          Positioned(
            right: 22,
            top: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: floatController,
              builder: (_, __) {
                final offset = (floatController.value * 2 - 1) * 6;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Center(
                    child: Text(
                      data.emoji,
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                );
              },
            ),
          ),
          // Layer 6 — content
          Positioned(
            left: 20,
            right: 120,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.eyebrow,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.title,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.sub,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.cta,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// RECENTLY VIEWED
// =========================================================================
class _RecentlyViewedSection extends StatelessWidget {
  final List<Product> products;
  const _RecentlyViewedSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Viewed',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text1,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/home/products'),
                  child: Text(
                    'See all ›',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 180,
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _RecentlyViewedCard(
                  product: products[i],
                  tileColor: _tileTints[i % _tileTints.length],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyViewedCard extends ConsumerWidget {
  final Product product;
  final Color tileColor;
  const _RecentlyViewedCard({
    required this.product,
    required this.tileColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _styleFor(product.category);
    return _TapScale(
      onTap: () => context.go('/home/product/${product.id}'),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: product.image1Url.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: CachedImage(
                            imageUrl: product.image1Url,
                            width: double.infinity,
                            height: 90,
                            placeholderIcon: Icons.shopping_bag_outlined,
                          ),
                        )
                      : Center(
                          child: Text(
                            style.emoji,
                            style: const TextStyle(fontSize: 38),
                          ),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _HeartButton(size: 24, productId: product.id),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.shortTitle.isNotEmpty
                        ? product.shortTitle
                        : product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.text2,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LKR ${_fmtPrice(product.priceLkr)}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StreetPin(businessId: product.businessId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// CATEGORY SECTION
// =========================================================================
class _CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Product> products;
  const _CategorySection({
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(categoryName);
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: style.badgeBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(style.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AppColors.text1,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        style.streetSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: AppColors.text4,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      context.go('/home/category/$categoryName'),
                  child: Text(
                    'See all ›',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal product scroll
          SizedBox(
            height: 240,
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _ProductCard(
                  product: products[i],
                  tileColor: _tileTints[i % _tileTints.length],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Dashed "See all" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => context.go('/home/category/$categoryName'),
              child: DottedBorder(
                color: AppColors.border,
                strokeWidth: 1.5,
                dashPattern: const [6, 4],
                radius: const Radius.circular(12),
                borderType: BorderType.RRect,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: AppColors.teal, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'See all $categoryName',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// PRODUCT CARD (width 150)
// =========================================================================
class _ProductCard extends ConsumerWidget {
  final Product product;
  final Color tileColor;
  const _ProductCard({required this.product, required this.tileColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _styleFor(product.category);
    final bizAsync =
        ref.watch(_homeBusinessByIdProvider(product.businessId));
    final isVerified = bizAsync.valueOrNull?.isVerified ?? false;

    return _TapScale(
      onTap: () => context.go('/home/product/${product.id}'),
      child: SizedBox(
        width: 150,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 108,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: product.image1Url.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: CachedImage(
                              imageUrl: product.image1Url,
                              width: double.infinity,
                              height: 108,
                              placeholderIcon: Icons.shopping_bag_outlined,
                            ),
                          )
                        : Center(
                            child: Text(style.emoji,
                                style: const TextStyle(fontSize: 44)),
                          ),
                  ),
                  if (isVerified)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '✓ Verified',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 8.5,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 7,
                    right: 7,
                    child: _HeartButton(size: 26, productId: product.id),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.shortTitle.isNotEmpty
                          ? product.shortTitle
                          : product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        color: AppColors.text2,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'LKR ${_fmtPrice(product.priceLkr)}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.text1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _StreetPin(businessId: product.businessId),
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

// =========================================================================
// STREET PIN — per-product business location
// =========================================================================
class _StreetPin extends ConsumerWidget {
  final String businessId;
  const _StreetPin({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(_homeBusinessByIdProvider(businessId));
    final street = bizAsync.valueOrNull?.location.trim() ?? '';
    final label = street.isEmpty ? 'Pettah' : street;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: AppColors.teal, size: 8),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// HEART BUTTON — local visual toggle
// =========================================================================
class _HeartButton extends ConsumerWidget {
  final double size;
  final String productId;
  const _HeartButton({required this.size, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final saved = authUser == null
        ? false
        : (ref
                .watch(_favoriteProductIdsProvider(authUser.uid))
                .valueOrNull ??
            const <String>{})
            .contains(productId);

    return GestureDetector(
      onTap: () {
        if (authUser == null) {
          ScaffoldMessenger.of(context).clearSnackBars();
          showSignInRequiredSheet(context);
          return;
        }
        ref.read(favoriteRepositoryProvider).toggle(
              userId: authUser.uid,
              targetType: 'product',
              targetId: productId,
            );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(size == 24 ? 6 : 8),
        ),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? AppColors.red : AppColors.text4,
          size: size * 0.5,
        ),
      ),
    );
  }
}

// =========================================================================
// HELPERS
// =========================================================================
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _down ? 0.965 : 1.0,
        child: widget.child,
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(_, Widget child, __) => child;
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Center(
        child: Text(
          'No products yet. Pull down to refresh.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
        ),
      ),
    );
  }
}

String _fmtPrice(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
