import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
      StreamProvider<List<Product>>(
          (ref) => ref.read(productRepositoryProvider).streamAll()),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('All Products')),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.inventory_2_outlined, title: 'No products')
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
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(p.title),
                      subtitle: Text(
                        'LKR ${p.priceLkr.toStringAsFixed(2)} • ${p.category}\nBusiness: ${p.businessId}',
                        maxLines: 2,
                      ),
                      trailing: Chip(
                        label: Text(p.isActive ? 'Active' : 'Inactive',
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor: p.isActive
                            ? Colors.green.withAlpha(30)
                            : Colors.red.withAlpha(30),
                      ),
                      isThreeLine: true,
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
