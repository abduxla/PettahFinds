import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/empty_state_widget.dart';

/// Business-side counterpart of [SearchScreen]. Mirrors the same UX shell
/// (floating search pill, 350 ms debounce, keep-focus during live typing)
/// but routes the query through `BusinessRepository.search` and renders
/// results as a vertical list of business cards rather than a product
/// grid. The map screen's "Search businesses" pill targets this screen so
/// the label finally matches the behavior.
class BusinessSearchScreen extends ConsumerStatefulWidget {
  const BusinessSearchScreen({super.key});

  @override
  ConsumerState<BusinessSearchScreen> createState() =>
      _BusinessSearchScreenState();
}

class _BusinessSearchScreenState extends ConsumerState<BusinessSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Business> _results = [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onQueryChanged);
  }

  // 350 ms debounce so typing "spice" fires Firestore once at the end of
  // the burst. `keepFocus: true` so the keyboard does not collapse between
  // strokes (same gotcha as the products search screen).
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
      _results = [];
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
    if (!keepFocus) FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _results = [];
    });
    try {
      final businesses =
          await ref.read(businessRepositoryProvider).search(query);
      if (mounted) {
        setState(() {
          _results = businesses;
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
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/map'),
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
                                hintText: 'Search businesses',
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
                          icon: Icons.storefront_outlined,
                          title: 'Search businesses',
                          subtitle:
                              'Find shops in Pettah by name, category, or street.',
                        )
                      : _results.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.storefront_outlined,
                              title: 'No businesses found',
                              subtitle:
                                  'Try a different keyword or spelling.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 120),
                              itemCount: _results.length,
                              itemBuilder: (_, i) =>
                                  _BusinessResultCard(business: _results[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card used in the search results list. Banner + logo + name +
/// category/location + (optional) rating. Tap navigates to the business
/// detail screen.
class _BusinessResultCard extends StatelessWidget {
  final Business business;
  const _BusinessResultCard({required this.business});

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
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
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
            CachedImage(
              imageUrl: business.bannerUrl,
              height: 110,
              width: double.infinity,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              placeholderIcon: Icons.storefront,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              theme.colorScheme.primary.withAlpha(40),
                          width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: business.logoUrl.isNotEmpty
                          ? NetworkImage(business.logoUrl)
                          : null,
                      child: business.logoUrl.isEmpty
                          ? Icon(Icons.store,
                              color: theme.colorScheme.primary, size: 18)
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
                              child: Text(
                                business.businessName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // VERIFIED BADGE — shown only on business own profile per spec.
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
                              size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(
                            business.ratingAvg.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[800],
                            ),
                          ),
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
