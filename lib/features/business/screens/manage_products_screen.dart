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
          return Scaffold(
            appBar: AppBar(title: const Text('Manage Products')),
            body: const EmptyStateWidget(
              icon: Icons.store_outlined,
              title: 'No business profile',
              subtitle: 'Set up your business first to manage products',
            ),
          );
        }
        final business = businessDynamic as Business;
        // Use streamAllByBusiness so inactive products still appear
        final productsAsync = ref.watch(
          StreamProvider<List<Product>>((ref) => ref
              .read(productRepositoryProvider)
              .streamAllByBusiness(business.id)),
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
                ? EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    subtitle: 'Add your first product to start selling',
                    actionLabel: 'Add Product',
                    onAction: () => context.go('/business/products/add'),
                  )
                : ListView.builder(
                    itemCount: products.length,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return _ProductTile(product: p, theme: theme, ref: ref);
                    },
                  ),
            loading: () => const _ManageProductsSkeleton(),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(currentUserBusinessProvider),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Manage Products')),
        body: const _ManageProductsSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Manage Products')),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentUserBusinessProvider),
        ),
      ),
    );
  }
}

class _ProductTile extends StatefulWidget {
  final Product product;
  final ThemeData theme;
  final WidgetRef ref;
  const _ProductTile({required this.product, required this.theme, required this.ref});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final theme = widget.theme;

    return Opacity(
      opacity: p.isActive ? 1.0 : 0.7,
      child: Container(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: p.isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          trailing: _toggling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton(
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
                          Text(p.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) async {
                    if (val == 'edit') {
                      context.go('/business/products/edit/${p.id}');
                    } else if (val == 'toggle') {
                      setState(() => _toggling = true);
                      try {
                        await widget.ref
                            .read(productRepositoryProvider)
                            .update(p.copyWith(isActive: !p.isActive));
                        if (context.mounted) {
                          context.showSuccessSnackBar(
                            p.isActive
                                ? 'Product deactivated'
                                : 'Product activated',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showErrorSnackBar(e);
                        }
                      } finally {
                        if (mounted) setState(() => _toggling = false);
                      }
                    }
                  },
                ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton matching the manage products list layout
class _ManageProductsSkeleton extends StatelessWidget {
  const _ManageProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              ShimmerBox(width: 56, height: 56, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(height: 12, radius: 6),
                  ],
                ),
              ),
              SizedBox(width: 12),
              ShimmerBox(width: 24, height: 24, radius: 12),
            ],
          ),
        ),
      ),
    );
  }
}
