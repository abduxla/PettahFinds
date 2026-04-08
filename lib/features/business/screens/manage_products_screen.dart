import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../core/extensions/context_extensions.dart';

class ManageProductsScreen extends ConsumerWidget {
  const ManageProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          appBar: AppBar(title: const Text('Manage Products')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/business/products/add'),
            icon: const Icon(Icons.add),
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
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CachedImage(
                            imageUrl: p.image1Url,
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(p.title),
                          subtitle: Text(
                            'LKR ${p.priceLkr.toStringAsFixed(2)} • ${p.category}',
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                    p.isActive ? 'Deactivate' : 'Activate'),
                              ),
                            ],
                            onSelected: (val) async {
                              if (val == 'edit') {
                                context
                                    .go('/business/products/edit/${p.id}');
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
            loading: () => const LoadingWidget(),
            error: (e, _) => AppErrorWidget(message: e.toString()),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}
