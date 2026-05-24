import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/product_review.dart';
import '../../../models/review.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/shimmer_loading.dart';

/// Read-only feed of customer reviews for the signed-in merchant. Two
/// tabs:
///   • Shop Reviews   — from /reviews where businessId == this business
///   • Product Reviews — from /productReviews where businessId == this
///                       business, grouped per product so the merchant
///                       can see which product a review is about.
///
/// Reached from Business Settings → "Customer Reviews".
class BusinessReviewsScreen extends ConsumerWidget {
  const BusinessReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          'Customer Reviews',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.text1,
          // Same canPop pattern used everywhere else in the business
          // shell — pop when there's a stack, otherwise fall back to
          // Settings (the entry point that pushed us).
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/business-settings'),
        ),
      ),
      body: businessAsync.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No business profile found.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: AppColors.white,
                  child: TabBar(
                    labelColor: AppColors.teal,
                    unselectedLabelColor: AppColors.text3,
                    indicatorColor: AppColors.teal,
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(text: 'Shop Reviews'),
                      Tab(text: 'Product Reviews'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ShopReviewsList(businessId: business.id),
                      _ProductReviewsList(businessId: business.id),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              ShimmerBox(height: 80, radius: 12),
              SizedBox(height: 10),
              ShimmerBox(height: 80, radius: 12),
              SizedBox(height: 10),
              ShimmerBox(height: 80, radius: 12),
            ],
          ),
        ),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
      ),
    );
  }
}

// =========================================================================
// Tab 1 — Shop-level reviews
// =========================================================================
class _ShopReviewsList extends ConsumerWidget {
  final String businessId;
  const _ShopReviewsList({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(businessReviewsProvider(businessId));
    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _EmptyReviews(
            label: 'No shop reviews yet',
            hint: "When customers rate your shop, you'll see it here.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ShopReviewTile(review: reviews[i]),
        );
      },
      loading: () => const _ReviewsSkeleton(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(businessReviewsProvider(businessId)),
      ),
    );
  }
}

class _ShopReviewTile extends StatelessWidget {
  final Review review;
  const _ShopReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
    );
  }
}

// =========================================================================
// Tab 2 — Per-product reviews (across every product owned by this biz)
// =========================================================================
class _ProductReviewsList extends ConsumerWidget {
  final String businessId;
  const _ProductReviewsList({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync =
        ref.watch(businessProductReviewsProvider(businessId));
    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _EmptyReviews(
            label: 'No product reviews yet',
            hint:
                'Reviews customers leave on specific products will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ProductReviewTile(review: reviews[i]),
        );
      },
      loading: () => const _ReviewsSkeleton(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(businessProductReviewsProvider(businessId)),
      ),
    );
  }
}

class _ProductReviewTile extends ConsumerWidget {
  final ProductReview review;
  const _ProductReviewTile({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(review.productId));
    final productLabel =
        productAsync.valueOrNull?.title.trim().isNotEmpty == true
            ? productAsync.valueOrNull!.title.trim()
            : 'Product';
    return _ReviewCard(
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt,
      topLabel: productLabel,
    );
  }
}

// =========================================================================
// Shared review tile
// =========================================================================
class _ReviewCard extends StatelessWidget {
  final double rating;
  final String comment;
  final DateTime createdAt;
  /// Optional pre-title (used by product-review tiles to surface the
  /// product name). Shop reviews omit it.
  final String? topLabel;

  const _ReviewCard({
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.topLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topLabel != null) ...[
            Text(
              topLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              _StarRow(rating: rating),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber[800],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(createdAt),
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment.trim(),
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

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// Renders five star icons, filled per `rating` (0.0 – 5.0).
class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }
}

// =========================================================================
// Empty + skeleton states
// =========================================================================
class _EmptyReviews extends StatelessWidget {
  final String label;
  final String hint;
  const _EmptyReviews({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_outlined,
                  color: AppColors.teal, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const ShimmerBox(height: 90, radius: 14),
    );
  }
}
