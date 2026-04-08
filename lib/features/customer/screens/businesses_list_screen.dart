import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
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
      appBar: AppBar(title: const Text('All Businesses')),
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
            onRefresh: () async => ref.invalidate(_allBusinessesProvider),
            child: ListView.builder(
              itemCount: businesses.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (_, i) {
                final b = businesses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => context.go('/home/business/${b.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        CachedImage(
                          imageUrl: b.logoUrl,
                          width: 80,
                          height: 80,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12)),
                          placeholderIcon: Icons.store,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(b.businessName,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (b.isVerified) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.verified,
                                          size: 16,
                                          color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${b.category} • ${b.location}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (b.ratingCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.star,
                                          size: 14,
                                          color: Colors.amber[700]),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${b.ratingAvg.toStringAsFixed(1)} (${b.ratingCount})',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_allBusinessesProvider),
        ),
      ),
    );
  }
}
