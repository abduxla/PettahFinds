import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../models/review.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../core/extensions/context_extensions.dart';

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
    final businessAsync = ref.watch(
      FutureProvider<Business>(
          (ref) => ref.read(businessRepositoryProvider).getById(widget.businessId)),
    );
    final productsAsync = ref.watch(
      StreamProvider<List<Product>>((ref) => ref
          .read(productRepositoryProvider)
          .streamByBusiness(widget.businessId)),
    );
    final reviewsAsync = ref.watch(
      StreamProvider<List<Review>>((ref) => ref
          .read(reviewRepositoryProvider)
          .streamByBusiness(widget.businessId)),
    );
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return businessAsync.when(
      data: (business) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(business.businessName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                background: CachedImage(
                  imageUrl: business.bannerUrl,
                  fit: BoxFit.cover,
                ),
              ),
              actions: [
                if (appUser != null)
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () {
                      ref.read(favoriteRepositoryProvider).toggle(
                            userId: appUser.uid,
                            targetType: 'business',
                            targetId: business.id,
                          );
                      context.showSnackBar('Favorite toggled');
                    },
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: business.logoUrl.isNotEmpty
                              ? NetworkImage(business.logoUrl)
                              : null,
                          child: business.logoUrl.isEmpty
                              ? const Icon(Icons.store)
                              : null,
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
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                  ),
                                  if (business.isVerified) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.verified,
                                        color: theme.colorScheme.primary),
                                  ],
                                ],
                              ),
                              Text(
                                  '${business.category} • ${business.location}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.outline)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (business.ratingCount > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: business.ratingAvg,
                            itemSize: 20,
                            itemBuilder: (_, __) =>
                                const Icon(Icons.star, color: Colors.amber),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount} reviews)',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(business.description,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    // Contact info
                    if (business.phone.isNotEmpty)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone),
                        title: Text(business.phone),
                      ),
                    if (business.email.isNotEmpty)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email),
                        title: Text(business.email),
                      ),
                    const Divider(height: 32),
                    // Products
                    Text('Products',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            productsAsync.when(
              data: (products) => products.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products yet'))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final p = products[i];
                          return ListTile(
                            leading: CachedImage(
                              imageUrl: p.image1Url,
                              width: 56,
                              height: 56,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            title: Text(p.title),
                            subtitle: Text(
                                'LKR ${p.priceLkr.toStringAsFixed(2)}'),
                            onTap: () =>
                                context.go('/home/product/${p.id}'),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(child: LoadingWidget()),
              error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(message: e.toString())),
            ),
            // Reviews section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Reviews',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Add review form
                    if (appUser != null && appUser.isUser)
                      _buildReviewForm(theme, appUser.uid),
                  ],
                ),
              ),
            ),
            reviewsAsync.when(
              data: (reviews) => reviews.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('No reviews yet. Be the first!'),
                      ))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final r = reviews[i];
                          return ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.person)),
                            title: RatingBarIndicator(
                              rating: r.rating,
                              itemSize: 16,
                              itemBuilder: (_, __) =>
                                  const Icon(Icons.star, color: Colors.amber),
                            ),
                            subtitle: Text(r.comment),
                          );
                        },
                        childCount: reviews.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(child: LoadingWidget()),
              error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(message: e.toString())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }

  Widget _buildReviewForm(ThemeData theme, String userId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _reviewFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Write a review', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                itemSize: 28,
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (val) => _rating = val,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentCtrl,
                decoration: const InputDecoration(hintText: 'Your review...'),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a comment' : null,
              ),
              const SizedBox(height: 8),
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
                              context.showSnackBar('Review submitted!');
                            }
                          } catch (e) {
                            if (mounted) {
                              context.showSnackBar(e.toString(),
                                  isError: true);
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _submittingReview = false);
                            }
                          }
                        },
                  child: _submittingReview
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
