import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/empty_state_widget.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  List<Business> _businesses = [];
  List<Product> _products = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _businesses = [];
      _products = [];
    });
    try {
      final results = await Future.wait([
        ref.read(businessRepositoryProvider).search(query),
        ref.read(productRepositoryProvider).search(query),
      ]);
      if (mounted) {
        setState(() {
          _businesses = results[0] as List<Business>;
          _products = results[1] as List<Product>;
        });
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search businesses & products...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          autofocus: true,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Businesses (${_businesses.length})'),
            Tab(text: 'Products (${_products.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const EmptyStateWidget(
                  icon: Icons.search,
                  title: 'Search for businesses or products',
                  subtitle: 'Enter a keyword to get started')
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _businesses.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.store_outlined,
                            title: 'No businesses found')
                        : ListView.builder(
                            itemCount: _businesses.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (_, i) {
                              final b = _businesses[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: b.logoUrl.isNotEmpty
                                      ? NetworkImage(b.logoUrl)
                                      : null,
                                  child: b.logoUrl.isEmpty
                                      ? const Icon(Icons.store)
                                      : null,
                                ),
                                title: Text(b.businessName),
                                subtitle: Text('${b.category} • ${b.location}'),
                                trailing: b.isVerified
                                    ? Icon(Icons.verified,
                                        color: theme.colorScheme.primary,
                                        size: 20)
                                    : null,
                                onTap: () =>
                                    context.go('/home/business/${b.id}'),
                              );
                            },
                          ),
                    _products.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.shopping_bag_outlined,
                            title: 'No products found')
                        : ListView.builder(
                            itemCount: _products.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              return ListTile(
                                leading: CachedImage(
                                  imageUrl: p.image1Url,
                                  width: 48,
                                  height: 48,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                title: Text(p.title),
                                subtitle:
                                    Text('LKR ${p.priceLkr.toStringAsFixed(2)}'),
                                onTap: () =>
                                    context.go('/home/product/${p.id}'),
                              );
                            },
                          ),
                  ],
                ),
    );
  }
}
