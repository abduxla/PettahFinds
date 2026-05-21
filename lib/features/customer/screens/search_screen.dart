import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/product.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/product_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onQueryChanged);
  }

  // Debounce live search so typing "phone" fires once at the end of the
  // typing burst instead of 5 separate Firestore reads. We pass
  // `keepFocus: true` so the keyboard stays open across debounced
  // searches — only an explicit submit (search button on the keyboard)
  // dismisses focus.
  void _onQueryChanged() {
    if (mounted) setState(() {});
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == q) _search(keepFocus: true);
    });
  }

  void _resetResults() {
    _searchCtrl.clear();
    setState(() {
      _products = [];
      _searched = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onQueryChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search({bool keepFocus = false}) async {
    if (_loading) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    // Only dismiss the keyboard on explicit submit. Debounced live searches
    // pass `keepFocus: true` so the keyboard stays open while the user
    // continues typing (otherwise the cursor disappears every 350ms).
    if (!keepFocus) FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _products = [];
    });
    try {
      final products =
          await ref.read(productRepositoryProvider).search(query);
      if (mounted) {
        setState(() {
          _products = products;
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
      body: SafeArea(
        child: Column(
          children: [
            // Header: back + floating search pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    // Pop back to whatever pushed us. Fall back to Home
                    // only when the search tab was reached via tab-switch
                    // (no stack to pop).
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(14),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 22, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(14),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: theme.colorScheme.outline, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search wholesale products',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                                filled: false,
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty || _searched)
                            GestureDetector(
                              onTap: _resetResults,
                              child: Icon(Icons.close_rounded,
                                  color: theme.colorScheme.outline,
                                  size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Results
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary),
                    )
                  : !_searched
                      ? const EmptyStateWidget(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Search products',
                          subtitle: 'Find products from Pettah businesses.',
                        )
                      : _products.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.shopping_bag_outlined,
                              title: 'No products found',
                              subtitle:
                                  'Try a different keyword or spelling.',
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 120),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                              ),
                              itemCount: _products.length,
                              itemBuilder: (_, i) =>
                                  ProductCard(product: _products[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// _ProductResultCard removed — replaced by the canonical ProductCard
// widget per the home-spec unification.
