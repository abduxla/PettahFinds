import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../models/favorite.dart';
import '../../../models/product.dart';
import '../../../models/product_review.dart';
import '../../../models/report.dart';
import '../../../utils/price_format.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/sign_in_required.dart';

final _productDetailProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  if (id.isEmpty) throw Exception('Invalid product');
  // Returns whether-active-or-not. The customer-facing branch of the
  // screen still gates on `product.isActive` and renders a "no
  // longer available" placeholder; the admin-mode branch needs to
  // load inactive products so it can review them and re-activate /
  // delete. The previous `throw if !isActive` here painted the
  // generic error UI immediately after an admin clicked Deactivate
  // (the post-write invalidate re-fetched and tripped the throw),
  // even though the deactivate had actually succeeded.
  return ref.watch(productRepositoryProvider).getById(id);
});

final _productSellerProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, businessId) {
  if (businessId.isEmpty) throw Exception('Missing seller');
  return ref.watch(businessRepositoryProvider).getById(businessId);
});

final _userFavoritesProvider =
    StreamProvider.autoDispose.family<List<Favorite>, String>((ref, uid) {
  return ref.watch(favoriteRepositoryProvider).streamByUser(uid);
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
    ref
        .read(recentlyViewedServiceProvider)
        .record(widget.productId)
        .then((_) {
      if (mounted) ref.invalidate(recentlyViewedProductsProvider);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final productAsync =
        ref.watch(_productDetailProvider(widget.productId));
    final appUser = ref.watch(appUserProvider).valueOrNull;
    // Read `?mode=` from the route. Three variants currently:
    //   • mode=owner — business owner previewing their OWN listing
    //     from the merchant dashboard. Swaps "Chat Seller" → "Edit
    //     Product".
    //   • mode=admin — admin reviewing a product from the admin
    //     business review screen. Swaps "Chat Seller" → Activate/
    //     Deactivate + Delete actions. Server-side enforced by the
    //     isAdmin() Firestore rule, but we also gate the UI on the
    //     signed-in AppUser's role so a curious non-admin can't see
    //     admin controls by editing the URL.
    //   • no mode — standard customer view.
    final mode = GoRouterState.of(context).uri.queryParameters['mode'];
    final isOwnerView = mode == 'owner';
    final isAdminView = mode == 'admin' && (appUser?.isAdmin ?? false);

    return productAsync.when(
      data: (product) {
        // Customers (and owner-preview) viewing an inactive product
        // get a friendly "no longer available" placeholder instead of
        // the full listing — the merchant or an admin has hidden it.
        // Admin mode SKIPS this gate because the whole point of
        // ?mode=admin is to review + un-hide / delete the product.
        if (!product.isActive && !isAdminView) {
          return _UnavailableProductScreen();
        }

        final businessAsync =
            ref.watch(_productSellerProvider(product.businessId));

        final isFavorited = appUser == null
            ? false
            : (ref.watch(_userFavoritesProvider(appUser.uid)).valueOrNull ?? [])
                .any((f) =>
                    f.targetType == 'product' && f.targetId == product.id);

        return Scaffold(
          backgroundColor: AppColors.bgSection,
          body: CustomScrollView(
            // ClampingScrollPhysics (not Bouncing). Bouncing on a pinned
            // SliverAppBar with FlexibleSpaceBar lets the user overscroll
            // past the hero, which separates the pinned header from the
            // sliver body and leaves a visible whitespace gap in the
            // middle of the screen. Clamping pins the top so the hero
            // and body stay flush at all times.
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                // stretch:false + an empty stretchModes list on the
                // FlexibleSpaceBar below stops the hero from stretching
                // on overscroll, which was another source of the gap.
                stretch: false,
                backgroundColor: AppColors.white,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      child: IconButton(
                        icon: Icon(
                          isFavorited
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFavorited
                              ? AppColors.red
                              : Colors.white,
                        ),
                        onPressed: () async {
                          if (appUser == null) {
                            ScaffoldMessenger.of(context)
                                .clearSnackBars();
                            showSignInRequiredSheet(context);
                            return;
                          }
                          try {
                            await ref
                                .read(favoriteRepositoryProvider)
                                .toggle(
                                  userId: appUser.uid,
                                  targetType: 'product',
                                  targetId: product.id,
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Could not update favorite: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  // Empty stretchModes — matches stretch:false on the
                  // SliverAppBar so an overscroll bounce can't stretch
                  // the hero away from the body sliver.
                  stretchModes: const [],
                  background: product.imageUrls.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            // Light backdrop behind contained image so
                            // tall portrait shots have a clean frame
                            // instead of falling onto the transparent
                            // app background.
                            Container(color: const Color(0xFFF5F5F5)),
                            PageView.builder(
                              itemCount: product.imageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _currentImageIndex = i),
                              itemBuilder: (_, i) => CachedImage(
                                imageUrl: product.imageUrls[i],
                                width: double.infinity,
                                height: 340,
                                // BoxFit.contain — show the whole hero
                                // image, never crop. Same call as the
                                // grid card so listing vs. detail can't
                                // disagree on what the user is buying.
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (product.imageUrls.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: List.generate(
                                    product.imageUrls.length,
                                    (i) => AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 300),
                                      width:
                                          _currentImageIndex == i ? 22 : 8,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: _currentImageIndex == i
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.55),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: AppColors.bgSection,
                          child: const Center(
                            child: Icon(Icons.shopping_bag_outlined,
                                size: 64, color: AppColors.text4),
                          ),
                        ),
                ),
              ),

              // ---- Body ----
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title.isNotEmpty
                              ? product.title
                              : 'Untitled product',
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        if (product.shortTitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.shortTitle,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.text3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        _PricingBlock(product: product),

                        if (product.category.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.bgSection,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.category_outlined,
                                    size: 13, color: AppColors.text3),
                                const SizedBox(width: 5),
                                Text(
                                  product.category,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 20),

                        Text(
                          'Description',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description.isNotEmpty
                              ? product.description
                              : 'No description provided.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            height: 1.55,
                            color: AppColors.text2,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const _PlatformDisclaimer(),

                        const SizedBox(height: 24),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 20),

                        Text(
                          'Sold by',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        businessAsync.when(
                          data: (business) => _SellerCard(
                            business: business,
                            productTitle: product.title,
                            isOwnerView: isOwnerView,
                            isAdminView: isAdminView,
                            productId: product.id,
                            product: product,
                          ),
                          loading: () =>
                              const ShimmerBox(height: 80, radius: 12),
                          // Friendly filler. Reaching this branch usually
                          // means the business is awaiting admin review
                          // (verified=false → Firestore rule denies a
                          // public read). Listing the product itself is
                          // already filtered out on customer screens, so
                          // this only triggers on direct deep-links or
                          // mid-rebuild races.
                          error: (_, _) => Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bgSection,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock_rounded,
                                    color: AppColors.text3, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Seller is awaiting verification. '
                                    'This page will unlock once the '
                                    'business is approved.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      color: AppColors.text2,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _openReportSheet(
                                context, ref, product.id),
                            icon: const Icon(Icons.flag_outlined,
                                size: 16, color: AppColors.text3),
                            label: Text(
                              'Report product',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Per-product reviews. Mirrors the business detail Reviews
              // section but pulls from `productReviews`.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: _ProductReviewsSection(product: product),
                ),
              ),

              // Bottom safe padding so the floating nav doesn't cover content.
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
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

/// Friendly placeholder shown when a non-admin opens a product whose
/// `isActive` flag is false — i.e. the merchant or an admin has
/// hidden the listing. Replaces the harsh `throw` that used to live
/// inside [_productDetailProvider] and paint the generic error
/// screen even right after an admin successfully deactivated.
class _UnavailableProductScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 56,
                color: AppColors.text4,
              ),
              const SizedBox(height: 16),
              Text(
                'This product is no longer available',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "The seller has hidden or removed this listing. "
                'Browse other products from Pettah businesses below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.text3,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final Business business;
  final String productTitle;
  /// True when the screen was opened with `?mode=owner` — i.e. the
  /// business owner is previewing their OWN listing from the merchant
  /// dashboard. Swaps the "Chat Seller" CTA at the bottom of the card
  /// for an "Edit Product" CTA, and hides the seller-info row's tap
  /// affordance (owners don't need to "view their own shop" from
  /// here).
  final bool isOwnerView;
  /// True when the screen was opened with `?mode=admin` AND the
  /// signed-in user actually has role=admin. Swaps the "Chat Seller"
  /// CTA for a row of admin actions (Activate/Deactivate + Delete).
  /// Set by the admin business review screen when an admin taps a
  /// product tile.
  final bool isAdminView;
  /// Product id needed by the Edit CTA when [isOwnerView] is true so
  /// it can deep-link into the existing /business/products/edit/:id
  /// form. Also passed to the admin actions widget.
  final String productId;
  /// Full product, only consumed by the admin actions widget so it
  /// can show the current active/inactive state on its toggle.
  final Product? product;
  const _SellerCard({
    required this.business,
    required this.productTitle,
    this.isOwnerView = false,
    this.isAdminView = false,
    this.productId = '',
    this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            // ADMIN MODE: do NOT push /home/business/:id — that's a
            // customer-shell route, and pushing it from the admin
            // shell triggers a cross-shell mount that re-registers
            // the customer shell's GlobalKey while the admin shell
            // still owns it → "GlobalKey used multiple times" +
            // navigator assertion crash. The admin already came from
            // /admin/businesses/review/:id; pop is the right gesture.
            // Owner mode also has nothing meaningful to navigate to,
            // so we no-op there too.
            onTap: (isAdminView || isOwnerView)
                ? null
                : () => context.push('/home/business/${business.id}'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.25), width: 2),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.tealLight,
                backgroundImage: business.logoUrl.isNotEmpty
                    ? NetworkImage(business.logoUrl)
                    : null,
                child: business.logoUrl.isEmpty
                    ? const Icon(Icons.store,
                        color: AppColors.teal, size: 20)
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
                        child: Text(
                          business.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      // VERIFIED BADGE — shown only on business own profile per spec.
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${business.category} • ${business.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: AppColors.text3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (business.ratingCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.orange),
                        const SizedBox(width: 2),
                        Text(
                          '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount})',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3),
          ],
        ),
          ),
          const SizedBox(height: 10),
          // Three-way bottom-slot swap. Admin > Owner > Customer
          // since an admin viewing the product takes precedence over
          // the owner-edit CTA (admins reviewing a merchant's own
          // listing should never see the merchant's Edit button).
          if (isAdminView && product != null)
            _AdminProductActions(product: product!)
          else if (isOwnerView)
            _EditProductButton(productId: productId)
          else
            _ChatSellerButton(business: business),
        ],
      ),
    );
  }
}

/// Admin-mode action row shown at the bottom of the seller card when
/// the screen was opened with `?mode=admin` AND the viewer's
/// AppUser.isAdmin is true. Both actions are server-enforced by the
/// `isAdmin()` Firestore rule on /products, so the UI gate is purely
/// for UX (don't surface controls a non-admin can't use anyway).
class _AdminProductActions extends ConsumerStatefulWidget {
  final Product product;
  const _AdminProductActions({required this.product});

  @override
  ConsumerState<_AdminProductActions> createState() =>
      _AdminProductActionsState();
}

class _AdminProductActionsState
    extends ConsumerState<_AdminProductActions> {
  bool _busy = false;

  Future<void> _toggleActive() async {
    final p = widget.product;
    setState(() => _busy = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .update(p.copyWith(isActive: !p.isActive));
      // Force the detail provider to re-fetch so the screen reflects
      // the new active state immediately (the in-stream rebuilds
      // covering the admin business detail list are a separate path).
      ref.invalidate(_productDetailProvider(p.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p.isActive
              ? 'Product deactivated — hidden from customers'
              : 'Product activated — visible to customers'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final p = widget.product;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this product?'),
        content: Text(
          '"${p.title}" will be permanently removed from this business\'s '
          'listings. The merchant will not be notified. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(productRepositoryProvider).hardDelete(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
      // Pop back to the admin business review screen; the products
      // stream there auto-reflects the removal.
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status pill — quick visual cue on whether the product is
        // currently visible to customers.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: p.isActive
                ? AppColors.tealLight
                : AppColors.red.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.isActive
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 14,
                color: p.isActive ? AppColors.teal : AppColors.red,
              ),
              const SizedBox(width: 6),
              Text(
                p.isActive
                    ? 'Active — visible to customers'
                    : 'Inactive — hidden from customers',
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: p.isActive ? AppColors.teal : AppColors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Activate / Deactivate
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleActive,
                  icon: Icon(
                    p.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(p.isActive ? 'Deactivate' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Hard delete
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 10),
          const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Owner-mode CTA shown at the bottom of the product detail when the
/// signed-in user is previewing their own listing from the merchant
/// dashboard. Pushes into the existing add/edit form.
class _EditProductButton extends StatelessWidget {
  final String productId;
  const _EditProductButton({required this.productId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: productId.isEmpty
            ? null
            : () => context.push('/edit-product/$productId'),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Edit Product'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Teal "Chat Seller" CTA. Reads the auth/app-user state so:
///   - guests get redirected to sign-in,
///   - the seller viewing their own product sees no button at all,
///   - other signed-in users open (or create) a thread and navigate to it.
class _ChatSellerButton extends ConsumerStatefulWidget {
  final Business business;
  const _ChatSellerButton({required this.business});

  @override
  ConsumerState<_ChatSellerButton> createState() =>
      _ChatSellerButtonState();
}

class _ChatSellerButtonState extends ConsumerState<_ChatSellerButton> {
  bool _opening = false;

  Future<void> _onTap(BuildContext context, String productId) async {
    if (_opening) return;
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to message sellers')),
      );
      // Small delay so the snackbar shows before the route swap.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
      context.go('/sign-in');
      return;
    }
    setState(() => _opening = true);
    try {
      final product = ref
          .read(_productDetailProvider(productId))
          .valueOrNull;
      if (product == null) {
        throw Exception('Product not loaded yet.');
      }
      final conv = await ref.read(chatServiceProvider).openConversation(
            product: product,
            business: widget.business,
            customerId: appUser.uid,
            // Denormalized on the conversation doc so the seller's inbox
            // can show "Alice" instead of the product title.
            customerName: appUser.displayName,
          );
      if (!context.mounted) return;
      // PUSH not GO so the user pops back to the product detail
      // (where they tapped Chat Seller) instead of being dumped on
      // the top-level inbox. See chat_list_screen tile for the
      // shell-stack rationale.
      context.push('/chat/${conv.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    // Seller viewing own product — no point chatting yourself.
    if (appUser != null &&
        appUser.isBusiness &&
        appUser.uid == widget.business.ownerUid) {
      return const SizedBox.shrink();
    }
    final productId =
        (context.findAncestorWidgetOfExactType<ProductDetailScreen>())
                ?.productId ??
            '';
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: _opening ? null : () => _onTap(context, productId),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: _opening
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
        label: Text(
          _opening ? 'Opening...' : 'Chat Seller',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PlatformDisclaimer extends StatelessWidget {
  const _PlatformDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSection,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.text4),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Listed by an independent business. PetaFinds does not sell, '
              'verify, or guarantee this product.',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openReportSheet(BuildContext context, WidgetRef ref, String productId) {
  final appUser = ref.read(appUserProvider).valueOrNull;
  if (appUser == null) {
    ScaffoldMessenger.of(context).clearSnackBars();
    showSignInRequiredSheet(context);
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportProductSheet(
      productId: productId,
      userId: appUser.uid,
    ),
  );
}

class _ReportProductSheet extends ConsumerStatefulWidget {
  final String productId;
  final String userId;
  const _ReportProductSheet({
    required this.productId,
    required this.userId,
  });

  @override
  ConsumerState<_ReportProductSheet> createState() =>
      _ReportProductSheetState();
}

class _ReportProductSheetState extends ConsumerState<_ReportProductSheet> {
  static const _reasons = [
    'Fake product',
    'Misleading price',
    'Wrong information',
    'Illegal item',
    'Other',
  ];

  String? _selected;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selected == null) {
      context.showErrorSnackBar('Please pick a reason');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(reportRepositoryProvider)
          .submit(Report(
            id: '',
            userId: widget.userId,
            productId: widget.productId,
            targetType: 'product',
            reason: _selected!,
            details: _detailsCtrl.text.trim().isEmpty
                ? null
                : _detailsCtrl.text.trim(),
            status: 'pending',
            createdAt: DateTime.now(),
          ))
          .timeout(const Duration(seconds: 15),
              onTimeout: () =>
                  throw Exception('Report timed out. Try again.'));
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessSnackBar('Report submitted. Thank you.');
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        context.showErrorSnackBar(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text('Report product',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 4),
          Text('Help us keep PetaFinds safe.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
              )),
          const SizedBox(height: 16),
          ..._reasons.map((r) => RadioListTile<String>(
                value: r,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Text(r,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text1,
                    )),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.teal,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Add details (optional)',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.text4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// PRICING — single retail price OR retail + wholesale tier breakdown
// =========================================================================
/// Renders the price area beneath the product title. Falls back to a
/// single LKR chip (the legacy look) when the product has no wholesale
/// tier, and expands into a two-row block ("Retail" / "Wholesale (MOQ N)")
/// when both wholesale fields are set on the product doc.
class _PricingBlock extends StatelessWidget {
  final Product product;
  const _PricingBlock({required this.product});

  String _money(double v) => 'LKR ${formatLkr(v)}';

  @override
  Widget build(BuildContext context) {
    if (!product.hasWholesaleTier) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _money(product.priceLkr),
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.teal,
            letterSpacing: -0.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriceRow(
            label: 'Retail',
            sub: 'per unit',
            amount: _money(product.priceLkr),
            emphasized: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: AppColors.border,
            ),
          ),
          _PriceRow(
            label: 'Wholesale',
            sub: 'MOQ ${product.minOrderQuantity}+ units',
            amount: _money(product.wholesalePriceLkr),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String sub;
  final String amount;
  final bool emphasized;
  const _PriceRow({
    required this.label,
    required this.sub,
    required this.amount,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text1,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text3,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.nunito(
            fontSize: emphasized ? 20 : 18,
            fontWeight: FontWeight.w800,
            color: AppColors.teal,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// PRODUCT REVIEWS — mirrors the business reviews block on businesses
// =========================================================================
class _ProductReviewsSection extends ConsumerStatefulWidget {
  final Product product;
  const _ProductReviewsSection({required this.product});

  @override
  ConsumerState<_ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState
    extends ConsumerState<_ProductReviewsSection> {
  final _formKey = GlobalKey<FormState>();
  final _commentCtrl = TextEditingController();
  double _rating = 5.0;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String uid) async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(productReviewRepositoryProvider).add(
            ProductReview(
              id: '',
              productId: widget.product.id,
              businessId: widget.product.businessId,
              userId: uid,
              rating: _rating,
              comment: _commentCtrl.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      _commentCtrl.clear();
      // Refresh the product so the new aggregate rating shows up.
      ref.invalidate(_productDetailProvider(widget.product.id));
      context.showSuccessSnackBar('Review submitted!');
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final reviewsAsync =
        ref.watch(productReviewsProvider(widget.product.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.text1,
              ),
            ),
            const Spacer(),
            if (widget.product.ratingCount > 0)
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.product.ratingAvg.toStringAsFixed(1)} '
                    '(${widget.product.ratingCount})',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Write a review — customers only. Business owners can't review
        // their own products and admins don't need to.
        if (appUser != null && appUser.isUser)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Write a review',
                    style: GoogleFonts.nunito(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    itemSize: 28,
                    unratedColor: const Color(0xFFE8E8E8),
                    itemBuilder: (_, _) => const Icon(
                        Icons.star_rounded,
                        color: Colors.amber),
                    onRatingUpdate: (v) => _rating = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Share your experience with this product...',
                    ),
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a comment'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed:
                          _submitting ? null : () => _submit(appUser.uid),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 44),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Reviews list (newest 100 via the live stream).
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              // Two empty states depending on auth:
              //   - signed-out: prompt the visitor to sign in so they
              //     can leave a review. Hides the "No reviews yet"
              //     phrasing because that reads as a missing review
              //     not a missing action.
              //   - signed-in: standard "No reviews yet · Be the
              //     first" copy with the form already rendered above.
              return _ReviewsEmptyState(isSignedIn: appUser != null);
            }
            return Column(
              children: [
                for (final r in reviews)
                  _ProductReviewTile(review: r),
                // Sign-in nudge after the list when the visitor is
                // signed out. Previously only shown when reviews were
                // empty — meaning a guest reading reviews had no path
                // to leave one of their own. Always-on prompt below
                // the list closes that gap.
                if (appUser == null) const _SignInToReviewPrompt(),
              ],
            );
          },
          loading: () =>
              const ShimmerBox(height: 80, radius: 14),
          // Graceful degrade. Errors at this surface are almost always
          // "the productReviews composite index isn't ready yet" right
          // after a fresh deploy — surfacing the raw Firestore message
          // tells the customer nothing useful and steals attention from
          // the rest of the page. Render the same empty-state we use
          // when the product genuinely has no reviews; the section will
          // self-heal once the index finishes building.
          //
          // SizedBox(width: double.infinity) + Center forces horizontal
          // centering inside the parent Column whose cross-axis is
          // pinned to start. Without it the inner Column collapsed to
          // its intrinsic width and stuck to the left edge.
          error: (_, _) => _ReviewsEmptyState(isSignedIn: appUser != null),
        ),
      ],
    );
  }
}

class _ProductReviewTile extends StatelessWidget {
  final ProductReview review;
  const _ProductReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.person_rounded,
                    size: 18, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              RatingBarIndicator(
                rating: review.rating,
                itemSize: 14,
                itemBuilder: (_, _) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                review.rating.toStringAsFixed(1),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber[800],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.5,
                color: AppColors.text2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline sign-in nudge appended below an EXISTING reviews list when
/// the visitor is signed out. Distinct from [_ReviewsEmptyState] which
/// replaces the list entirely; this one supplements it so a guest
/// reading reviews still sees a clear path to leaving one of their own.
class _SignInToReviewPrompt extends StatelessWidget {
  const _SignInToReviewPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 28,
            color: Color(0xFF9E9E9E),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to leave a review',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.push('/sign-in'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state widget for review surfaces.
///
/// - Signed-out visitor: nudges them to sign in (only signed-in users
///   can leave a review per the Firestore rules anyway).
/// - Signed-in user: standard "be the first" copy.
///
/// Shared between product and business review sections so both
/// surfaces speak in one voice.
class _ReviewsEmptyState extends StatelessWidget {
  final bool isSignedIn;
  const _ReviewsEmptyState({required this.isSignedIn});

  static const _muted = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.rate_review_outlined,
                size: 36, color: _muted),
            const SizedBox(height: 10),
            Text(
              isSignedIn
                  ? 'No reviews yet'
                  : 'Sign in to leave a review',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
            if (isSignedIn) ...[
              const SizedBox(height: 2),
              Text(
                'Be the first to leave one.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _muted,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push('/sign-in'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
