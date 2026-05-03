import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../models/review.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/sign_in_required.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../utils/whatsapp.dart';

// Stable family providers — defined top-level so `ref.invalidate` targets
// the same instance the UI is watching and rebuilds don't re-subscribe.
final _businessByIdProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, id) {
  if (id.isEmpty) throw Exception('Invalid business');
  return ref.watch(businessRepositoryProvider).getById(id);
});

final _businessProductsProvider =
    StreamProvider.autoDispose.family<List<Product>, String>((ref, id) {
  return ref.watch(productRepositoryProvider).streamByBusiness(id);
});

final _businessReviewsProvider =
    StreamProvider.autoDispose.family<List<Review>, String>((ref, id) {
  return ref.watch(reviewRepositoryProvider).streamByBusiness(id);
});

class BusinessDetailScreen extends ConsumerStatefulWidget {
  final String businessId;
  const BusinessDetailScreen({super.key, required this.businessId});

  @override
  ConsumerState<BusinessDetailScreen> createState() =>
      _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  final _reviewFormKey = GlobalKey<FormState>();
  final _commentCtrl = TextEditingController();
  double _rating = 5.0;
  bool _submittingReview = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final businessAsync =
        ref.watch(_businessByIdProvider(widget.businessId));
    final productsAsync =
        ref.watch(_businessProductsProvider(widget.businessId));
    final reviewsAsync =
        ref.watch(_businessReviewsProvider(widget.businessId));
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return businessAsync.when(
      data: (business) => Scaffold(
        body: CustomScrollView(
          slivers: [
            // Hero banner with overlay controls
            SliverAppBar(
              expandedHeight: 220,
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
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border,
                          color: Colors.white),
                      onPressed: () {
                        if (appUser == null) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          showSignInRequiredSheet(context);
                          return;
                        }
                        ref.read(favoriteRepositoryProvider).toggle(
                              userId: appUser.uid,
                              targetType: 'business',
                              targetId: business.id,
                            );
                        context.showSuccessSnackBar('Favorite toggled');
                      },
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedImage(
                      imageUrl: business.bannerUrl,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.storefront,
                    ),
                    // Gradient overlay for readability
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black38],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Business info card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(40),
                                  width: 2.5),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              backgroundImage: business.logoUrl.isNotEmpty
                                  ? NetworkImage(business.logoUrl)
                                  : null,
                              child: business.logoUrl.isEmpty
                                  ? Icon(Icons.store,
                                      color: theme.colorScheme.primary,
                                      size: 24)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(business.businessName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (business.isVerified) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.verified,
                                          size: 20,
                                          color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(business.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                theme.colorScheme.primary,
                                          )),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(business.location,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.outline,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Rating
                      if (business.ratingCount > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RatingBarIndicator(
                                rating: business.ratingAvg,
                                itemSize: 18,
                                itemBuilder: (_, __) => const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount} reviews)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Description
                      if (business.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(business.description,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color:
                                  theme.colorScheme.onSurface.withAlpha(180),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Contact info
            if (business.phone.isNotEmpty ||
                business.email.isNotEmpty ||
                business.whatsappNumber.trim().isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
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
                    child: Column(
                      children: [
                        if (business.phone.isNotEmpty)
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.phone_rounded,
                                  size: 18, color: Color(0xFF16A34A)),
                            ),
                            title: Text(business.phone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        if (business.whatsappNumber.trim().isNotEmpty) ...[
                          if (business.phone.isNotEmpty)
                            Divider(
                                height: 1,
                                indent: 60,
                                color: theme.dividerTheme.color),
                          ListTile(
                            dense: true,
                            onTap: () => launchWhatsApp(
                              context: context,
                              rawNumber: business.whatsappNumber,
                              message:
                                  'Hi, I found your business on PetaFinds. '
                                  'I want to inquire about your products.',
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chat_bubble_rounded,
                                  size: 18, color: Color(0xFF25D366)),
                            ),
                            title: Text(business.whatsappNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                            subtitle: const Text('Chat on WhatsApp',
                                style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.open_in_new,
                                size: 16, color: Color(0xFF25D366)),
                          ),
                        ],
                        if (business.email.isNotEmpty &&
                            (business.phone.isNotEmpty ||
                                business.whatsappNumber.trim().isNotEmpty))
                          Divider(
                              height: 1,
                              indent: 60,
                              color: theme.dividerTheme.color),
                        if (business.email.isNotEmpty)
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EAF6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.email_rounded,
                                  size: 18, color: Color(0xFF5C6BC0)),
                            ),
                            title: Text(business.email,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Products section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text('Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: theme.colorScheme.onSurface,
                    )),
              ),
            ),

            // Products list
            productsAsync.when(
              data: (products) => products.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products yet',
                        subtitle: 'This business hasn\'t added products yet.',
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final p = products[i];
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () =>
                                    context.go('/home/product/${p.id}'),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: CachedImage(
                                          imageUrl: p.image1Url,
                                          width: 64,
                                          height: 64,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          placeholderIcon:
                                              Icons.shopping_bag_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(p.title,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(
                                              'LKR ${p.priceLkr.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: theme
                                                    .colorScheme.primary,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: theme.colorScheme.outline,
                                          size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ShimmerBox(height: 80),
                      SizedBox(height: 10),
                      ShimmerBox(height: 80),
                      SizedBox(height: 10),
                      ShimmerBox(height: 80),
                    ],
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(message: e.toString())),
            ),

            // Reviews section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text('Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: theme.colorScheme.onSurface,
                    )),
              ),
            ),

            // Review form
            if (appUser != null && appUser.isUser)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: _buildReviewForm(theme, appUser.uid),
                ),
              ),

            // Reviews list
            reviewsAsync.when(
              data: (reviews) => reviews.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 36,
                                  color: theme.colorScheme.outline),
                              const SizedBox(height: 8),
                              Text('No reviews yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.outline,
                                  )),
                              const SizedBox(height: 4),
                              Text('Be the first to leave a review!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final r = reviews[i];
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
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
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: theme
                                            .colorScheme.primaryContainer,
                                        child: Icon(Icons.person_rounded,
                                            size: 18,
                                            color:
                                                theme.colorScheme.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      RatingBarIndicator(
                                        rating: r.rating,
                                        itemSize: 14,
                                        itemBuilder: (_, __) => const Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(r.rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber[800],
                                          )),
                                    ],
                                  ),
                                  if (r.comment.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(r.comment,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: theme.colorScheme.onSurface
                                              .withAlpha(200),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: reviews.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: ShimmerBox(height: 100),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(message: e.toString())),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) => Scaffold(
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_businessByIdProvider(widget.businessId)),
        ),
      ),
    );
  }

  Widget _buildReviewForm(ThemeData theme, String userId) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Form(
        key: _reviewFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Write a review',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              itemSize: 28,
              unratedColor: const Color(0xFFE8E8E8),
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: Colors.amber),
              onRatingUpdate: (val) => _rating = val,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
              ),
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a comment' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submittingReview
                    ? null
                    : () async {
                        if (!_reviewFormKey.currentState!.validate()) return;
                        setState(() => _submittingReview = true);
                        try {
                          await ref.read(reviewRepositoryProvider).add(
                                Review(
                                  id: '',
                                  businessId: widget.businessId,
                                  userId: userId,
                                  rating: _rating,
                                  comment: _commentCtrl.text.trim(),
                                  createdAt: DateTime.now(),
                                ),
                              );
                          _commentCtrl.clear();
                          if (mounted) {
                            context.showSuccessSnackBar('Review submitted!');
                          }
                        } catch (e) {
                          if (mounted) {
                            context.showSnackBar(e.toString(), isError: true);
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _submittingReview = false);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 44),
                ),
                child: _submittingReview
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
    );
  }
}
