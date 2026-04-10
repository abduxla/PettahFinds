import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

final _allBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamAll();
});

class BusinessesListScreen extends ConsumerWidget {
  const BusinessesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessesAsync = ref.watch(_allBusinessesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Businesses'),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      body: businessesAsync.when(
        data: (businesses) {
          if (businesses.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.store_outlined,
              title: 'No businesses found',
              subtitle: 'Check back later for new businesses.',
            );
          }
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: () async => ref.invalidate(_allBusinessesProvider),
            child: ListView.builder(
              itemCount: businesses.length,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemBuilder: (_, i) => _BusinessListCard(business: businesses[i]),
            ),
          );
        },
        loading: () => const BusinessCardSkeleton(count: 4),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_allBusinessesProvider),
        ),
      ),
    );
  }
}

class _BusinessListCard extends StatelessWidget {
  final Business business;
  const _BusinessListCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/home/business/${business.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            CachedImage(
              imageUrl: business.bannerUrl,
              height: 130,
              width: double.infinity,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              placeholderIcon: Icons.storefront,
            ),
            // Info row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(40),
                          width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: business.logoUrl.isNotEmpty
                          ? NetworkImage(business.logoUrl)
                          : null,
                      child: business.logoUrl.isEmpty
                          ? Icon(Icons.store,
                              color: theme.colorScheme.primary, size: 20)
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
                              child: Text(business.businessName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (business.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified,
                                  size: 16, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${business.category} • ${business.location}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (business.ratingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(business.ratingAvg.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[800],
                              )),
                        ],
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
