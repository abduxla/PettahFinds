import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (businessDynamic) {
        if (businessDynamic == null) {
          return const Scaffold(body: Center(child: Text('No business')));
        }
        final business = businessDynamic as Business;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Business Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.go('/business-profile/edit'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner
                CachedImage(
                  imageUrl: business.bannerUrl,
                  height: 180,
                  width: double.infinity,
                  placeholderIcon: Icons.storefront,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: business.logoUrl.isNotEmpty
                                ? NetworkImage(business.logoUrl)
                                : null,
                            child: business.logoUrl.isEmpty
                                ? const Icon(Icons.store, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 16),
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
                                                  fontWeight:
                                                      FontWeight.bold)),
                                    ),
                                    if (business.isVerified) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.verified,
                                          color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${business.category} • ${business.membershipTier.toUpperCase()}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (business.ratingCount > 0) ...[
                        const SizedBox(height: 16),
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
                                '${business.ratingAvg.toStringAsFixed(1)} (${business.ratingCount} reviews)'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(business.description,
                          style: theme.textTheme.bodyMedium),
                      const Divider(height: 32),
                      _InfoRow(Icons.location_on, business.location),
                      _InfoRow(Icons.phone, business.phone),
                      _InfoRow(Icons.email, business.email),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }
}
