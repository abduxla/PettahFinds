import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

class CategoryBusinessesScreen extends ConsumerWidget {
  final String categoryName;
  const CategoryBusinessesScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stream = ref.watch(
      StreamProvider<List<Business>>((ref) {
        return ref
            .watch(businessRepositoryProvider)
            .streamByCategory(categoryName);
      }),
    );

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: stream.when(
        data: (businesses) => businesses.isEmpty
            ? EmptyStateWidget(
                icon: Icons.store_outlined,
                title: 'No businesses in $categoryName')
            : ListView.builder(
                itemCount: businesses.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final b = businesses[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: b.logoUrl.isNotEmpty
                            ? NetworkImage(b.logoUrl)
                            : null,
                        child: b.logoUrl.isEmpty
                            ? const Icon(Icons.store)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(b.businessName)),
                          if (b.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16, color: theme.colorScheme.primary),
                          ],
                        ],
                      ),
                      subtitle: Text(b.location),
                      trailing: b.ratingCount > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star,
                                    size: 16, color: Colors.amber[700]),
                                Text(
                                    ' ${b.ratingAvg.toStringAsFixed(1)}'),
                              ],
                            )
                          : null,
                      onTap: () => context.go('/home/business/${b.id}'),
                    ),
                  );
                },
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}
