import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
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

  /// Returns the products list sorted per the active SearchSortOption.
  /// In-memory only — does NOT issue a new Firestore query, so no
  /// composite index is required for any sort mode.
  List<Product> _sortedProducts(SearchSortOption? mode) {
    if (mode == null) return _products;
    final out = [..._products];
    switch (mode) {
      case SearchSortOption.bestReviewed:
        out.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
        break;
      case SearchSortOption.priceAsc:
        out.sort((a, b) => a.priceLkr.compareTo(b.priceLkr));
        break;
      case SearchSortOption.priceDesc:
        out.sort((a, b) => b.priceLkr.compareTo(a.priceLkr));
        break;
      case SearchSortOption.mostFeatured:
        // TODO(featured): switch to a real `isFeatured` bool on Product
        // when admin/merchant tooling for promoting listings lands. For
        // now newest-first is the closest proxy.
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSort = ref.watch(searchSortProvider);
    final visibleProducts = _sortedProducts(activeSort);

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
                  const SizedBox(width: 10),
                  // Filter / sort button — opens the sort bottom sheet.
                  // Shows a small active-dot when a non-default sort is
                  // selected so users see they're filtered without
                  // re-opening the sheet.
                  _SortFilterButton(theme: theme),
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
                      : visibleProducts.isEmpty
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
                              itemCount: visibleProducts.length,
                              itemBuilder: (_, i) => ProductCard(
                                product: visibleProducts[i],
                                searchVariant: true,
                              ),
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

/// Filter / sort affordance shown at the right of the search bar.
/// Live-reads the active sort from `searchSortProvider` so the active
/// dot toggles instantly when the bottom sheet writes a new value.
class _SortFilterButton extends ConsumerWidget {
  final ThemeData theme;
  const _SortFilterButton({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(searchSortProvider) != null;
    return GestureDetector(
      onTap: () => _showSortSheet(context, ref),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? AppColors.tealLight : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              active ? Icons.tune_rounded : Icons.tune_outlined,
              size: 22,
              color: active ? AppColors.teal : theme.colorScheme.onSurface,
            ),
            if (active)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8821A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the sort/filter modal. Returns nothing — selection is written
/// straight into `searchSortProvider` so the parent grid re-sorts on
/// dismiss.
void _showSortSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => const _SortSheet(),
  );
}

class _SortSheet extends ConsumerStatefulWidget {
  const _SortSheet();

  @override
  ConsumerState<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends ConsumerState<_SortSheet> {
  SearchSortOption? _draft;

  @override
  void initState() {
    super.initState();
    // Seed with the currently-active sort so re-opening the sheet shows
    // the user's previous selection pre-armed.
    _draft = ref.read(searchSortProvider);
  }

  static const _options = <(SearchSortOption, String)>[
    (SearchSortOption.bestReviewed, 'Best Reviewed'),
    (SearchSortOption.priceAsc, 'Price: Low to High'),
    (SearchSortOption.priceDesc, 'Price: High to Low'),
    (SearchSortOption.mostFeatured, 'Most Featured'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Sort & Filter',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in _options)
              _SortRow(
                label: entry.$2,
                selected: _draft == entry.$1,
                onTap: () => setState(() => _draft = entry.$1),
              ),
            const SizedBox(height: 8),
            // Clear shortcut — sets selection back to null (default order).
            TextButton(
              onPressed: () => setState(() => _draft = null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.text3,
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(36),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                'Clear sort',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ref.read(searchSortProvider.notifier).state = _draft;
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Apply',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.teal : AppColors.text1,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 20, color: AppColors.teal),
          ],
        ),
      ),
    );
  }
}
