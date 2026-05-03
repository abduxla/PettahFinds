import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/business.dart';
import '../../../models/favorite.dart';
import '../../../models/product.dart';
import '../../../models/report.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/sign_in_required.dart';
import '../../../utils/whatsapp.dart';

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

    return productAsync.when(
      data: (product) {
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
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
                        onPressed: () {
                          if (appUser == null) {
                            ScaffoldMessenger.of(context)
                                .clearSnackBars();
                            showSignInRequiredSheet(context);
                            return;
                          }
                          ref.read(favoriteRepositoryProvider).toggle(
                                userId: appUser.uid,
                                targetType: 'product',
                                targetId: product.id,
                              );
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

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'LKR ${product.priceLkr.toStringAsFixed(0)}',
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.teal,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),

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
                          ),
                          loading: () =>
                              const ShimmerBox(height: 80, radius: 12),
                          error: (_, _) => OutlinedButton.icon(
                            onPressed: product.businessId.isEmpty
                                ? null
                                : () => context.go(
                                    '/home/business/${product.businessId}'),
                            icon: const Icon(Icons.store),
                            label: const Text('View Business'),
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

              // Bottom safe padding so the floating nav doesn't cover content.
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
  final String productTitle;
  const _SellerCard({required this.business, required this.productTitle});

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
            onTap: () => context.go('/home/business/${business.id}'),
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
                      if (business.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 15, color: AppColors.teal),
                      ],
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
          if (business.whatsappNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: () => launchWhatsApp(
                  context: context,
                  rawNumber: business.whatsappNumber,
                  message:
                      'Hi, I saw your product on PetaFinds: $productTitle. '
                      'I want to inquire about it.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble, size: 16),
                label: Text(
                  'Chat on WhatsApp',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Business WhatsApp not available',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.text4,
              ),
            ),
          ],
        ],
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
