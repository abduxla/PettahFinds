import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../core/extensions/context_extensions.dart';

class ManageProductsScreen extends ConsumerWidget {
  const ManageProductsScreen({super.key});

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
        final productsAsync = ref.watch(
          StreamProvider<List<Product>>((ref) => ref
              .read(productRepositoryProvider)
              .streamByBusiness(business.id)),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Products'),
            titleTextStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/business/products/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Product'),
          ),
          body: productsAsync.when(
            data: (products) => products.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    subtitle: 'Tap + to add your first product')
                : ListView.builder(
                    itemCount: products.length,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedImage(
                              imageUrl: p.image1Url,
                              width: 56,
                              height: 56,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          title: Text(p.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Row(
                            children: [
                              Text(
                                'LKR ${p.priceLkr.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                ' • ${p.category}',
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            icon: Icon(Icons.more_vert_rounded,
                                color: theme.colorScheme.outline),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  )),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      p.isActive
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(p.isActive
                                        ? 'Deactivate'
                                        : 'Activate'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (val) async {
                              if (val == 'edit') {
                                context.go('/business/products/edit/${p.id}');
                              } else if (val == 'toggle') {
                                try {
                                  await ref
                                      .read(productRepositoryProvider)
                                      .update(p.copyWith(
                                          isActive: !p.isActive));
                                  if (context.mounted) {
                                    context.showSnackBar(p.isActive
                                        ? 'Product deactivated'
                                        : 'Product activated');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    context.showSnackBar(e.toString(),
                                        isError: true);
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerBox(height: 300),
            ),
            error: (e, _) => AppErrorWidget(message: e.toString()),
          ),
        );
      },
      loading: () => const Scaffold(body: DetailSkeleton()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}
