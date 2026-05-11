import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/verify_email_banner.dart';

/// Merchant dashboard — uses the same visual language as the customer
/// home: Teal-Dark header with "Merchant Hub." logo + bell, bgSection
/// canvas, white section cards with 1 px `AppColors.border`, Nunito
/// headings + DM Sans labels, no hardcoded hexes.
class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (business) {
        if (business == null) {
          return Scaffold(
            backgroundColor: AppColors.bgSection,
            body: EmptyStateWidget(
              icon: Icons.store_outlined,
              title: 'Set up your business',
              subtitle: 'Create your business profile to start selling',
              actionLabel: 'Set Up Business',
              onAction: () => context.go('/business/setup'),
            ),
          );
        }
        final productsAsync =
            ref.watch(businessActiveProductsProvider(business.id));
        final products = productsAsync.valueOrNull ?? const <Product>[];

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
                  ref.invalidate(currentUserBusinessProvider);
                  ref.invalidate(businessActiveProductsProvider(business.id));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // ---- Teal-dark header (matches customer home) ----
                    SliverToBoxAdapter(child: _MerchantHeader(business: business)),

                    // ---- Email verification nudge ----
                    const SliverToBoxAdapter(child: VerifyEmailBanner()),

                    // ---- Welcome + CTA (white section) ----
                    SliverToBoxAdapter(
                      child: _WelcomeSection(business: business),
                    ),

                    // ---- Stats (white section) ----
                    SliverToBoxAdapter(
                      child: _StatsSection(
                        business: business,
                        productCount: products.length,
                      ),
                    ),

                    // ---- Recent products (white section) ----
                    SliverToBoxAdapter(
                      child: productsAsync.when(
                        data: (list) => _RecentProductsSection(products: list),
                        loading: () => const _RecentProductsSkeleton(),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AppErrorWidget(
                            message: e.toString(),
                            onRetry: () => ref.invalidate(
                                businessActiveProductsProvider(business.id)),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) => Scaffold(
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
      ),
    );
  }
}

// =========================================================================
// TEAL HEADER — "Merchant Hub." logo + notifications bell
// =========================================================================
class _MerchantHeader extends StatelessWidget {
  final Business business;
  const _MerchantHeader({required this.business});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.tealDark,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Merchant Hub',
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
                business.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.go('/business/notifications'),
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              child: const Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 20),
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
// WELCOME + CTA
// =========================================================================
class _WelcomeSection extends StatelessWidget {
  final Business business;
  const _WelcomeSection({required this.business});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.text3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  business.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text1,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
              ),
              if (business.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified,
                    size: 18, color: AppColors.teal),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PrimaryAction(
                icon: Icons.add,
                label: 'Add Product',
                onTap: () => context.go('/business/products/add'),
              ),
              const SizedBox(width: 10),
              _SecondaryAction(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () => context.go('/business-profile/edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.teal, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
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
// STATS — 3 tiles inside a white section card
// =========================================================================
class _StatsSection extends StatelessWidget {
  final Business business;
  final int productCount;
  const _StatsSection({
    required this.business,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Numbers',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.teal,
                  tileColor: AppColors.tealLight,
                  label: 'Products',
                  value: productCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.orange,
                  tileColor: const Color(0xFFFFF4E5),
                  label: 'Rating',
                  value: business.ratingCount > 0
                      ? business.ratingAvg.toStringAsFixed(1)
                      : 'N/A',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: AppColors.text2,
                  tileColor: AppColors.bgSection,
                  label: 'Tier',
                  value: business.membershipTier.toUpperCase(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.text1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// RECENT PRODUCTS — horizontal scroll of product cards
// =========================================================================
class _RecentProductsSection extends StatelessWidget {
  final List<Product> products;
  const _RecentProductsSection({required this.products});

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
                  'Your Products',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text1,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/business/products'),
                  child: Text(
                    'View all ›',
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
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 40, color: AppColors.text4),
                    const SizedBox(height: 10),
                    Text(
                      'No products yet',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.text1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () =>
                          context.go('/business/products/add'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Add First Product',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
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
                  itemBuilder: (_, i) =>
                      _MerchantProductCard(product: products[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentProductsSkeleton extends StatelessWidget {
  const _RecentProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: const ShimmerBox(height: 220, radius: 12),
    );
  }
}

// Same product-card shape as customer home (width 150, 108px image, teal
// price, bottom-right active/inactive pin instead of heart).
class _MerchantProductCard extends StatelessWidget {
  final Product product;
  const _MerchantProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.go('/business/products/edit/${product.id}'),
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
                      color: AppColors.bgSection,
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
                              placeholderIcon:
                                  Icons.shopping_bag_outlined,
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.shopping_bag_outlined,
                                color: AppColors.text4, size: 32),
                          ),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? AppColors.tealLight
                            : AppColors.red.withValues(alpha: 0.12),
                        border: Border.all(
                          color: product.isActive
                              ? AppColors.teal.withValues(alpha: 0.2)
                              : AppColors.red.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          color: product.isActive
                              ? AppColors.teal
                              : AppColors.red,
                        ),
                      ),
                    ),
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
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined,
                            color: AppColors.text4, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          'Tap to edit',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                            color: AppColors.text4,
                          ),
                        ),
                      ],
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

// =========================================================================
// Helpers
// =========================================================================
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(_, Widget child, __) => child;
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
