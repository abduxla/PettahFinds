import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/categories.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_colors.dart';
import '../models/product.dart';
import 'cached_image.dart';
import 'sign_in_required.dart';

/// Canonical customer-facing product card. Single source of truth used
/// by home, products list, search, and saved (favorites) so every
/// listing surface shows the same shape: image with tile-tint
/// background, title, price, street-pin chip, heart-toggle button.
///
/// Per spec: NO verified badge (lives only on /business-profile), NO
/// category line, NO extra metadata.
///
/// Width is parameterized so the card works both inside horizontal
/// scrollers (home, recently viewed) at a fixed 150–160 width AND
/// inside 2-col grids where the parent decides width.
class ProductCard extends ConsumerWidget {
  final Product product;

  /// Tile background behind the image area. Callers can pass per-card
  /// tints to vary the look across a list (home does this); grids
  /// usually pass null and accept the default warm peach.
  final Color? tileColor;

  /// Optional fixed card width. Pass when the card lives in a
  /// horizontal scroller (no parent width constraint). Leave null
  /// inside grids — the grid sizes the card.
  final double? width;

  /// Image area height. Defaults to the home-card spec (108) — grids
  /// can override if they need a different aspect.
  final double imageHeight;

  static const _defaultTint = Color(0xFFFEF3E8);

  const ProductCard({
    super.key,
    required this.product,
    this.tileColor,
    this.width,
    this.imageHeight = 108,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = _emojiFor(product.category);
    final bg = tileColor ?? _defaultTint;

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: imageHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: product.image1Url.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: CachedImage(
                          imageUrl: product.image1Url,
                          width: double.infinity,
                          height: imageHeight,
                          placeholderIcon: Icons.shopping_bag_outlined,
                        ),
                      )
                    : Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 44)),
                      ),
              ),
              // VERIFIED BADGE — shown only on business own profile per spec.
              Positioned(
                bottom: 7,
                right: 7,
                child: _HeartButton(size: 26, productId: product.id),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.shortTitle.isNotEmpty
                      ? product.shortTitle
                      : product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: AppColors.text2,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LKR ${_fmtPrice(product.priceLkr)}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.text1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                _StreetPin(businessId: product.businessId),
              ],
            ),
          ),
        ],
      ),
    );

    final tappable = _TapScale(
      onTap: () => context.go('/home/product/${product.id}'),
      child: card,
    );

    return width != null
        ? SizedBox(width: width, child: tappable)
        : tappable;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers — kept private to this file. Home screen has its own
// near-duplicate copies for the smaller "recently viewed" cards; that's
// intentional, the two card variants don't share enough scaffolding to
// justify a third shared module.
// ---------------------------------------------------------------------------

const Map<String, String> _categoryEmoji = {
  'Electronics': '📱',
  'Clothing': '👗',
  'Grocery': '🛒',
  'Food & Drink': '🍽️',
  'Spices': '🌶️',
  'Jewellery': '💎',
  'Home & Living': '🏠',
  'Beauty & Wellness': '💄',
  'Services': '🛠️',
  'Sports & Outdoors': '⚽',
  'Stationery & Books': '📚',
  'Toys & Kids': '🧸',
  'Other': '🛍️',
};

String _emojiFor(String raw) =>
    _categoryEmoji[AppCategories.normalize(raw)] ?? '🛍️';

String _fmtPrice(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _StreetPin extends ConsumerWidget {
  final String businessId;
  const _StreetPin({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(businessByIdProvider(businessId));
    final street = bizAsync.valueOrNull?.location.trim() ?? '';
    final label = street.isEmpty ? 'Pettah' : street;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: AppColors.teal, size: 8),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartButton extends ConsumerWidget {
  final double size;
  final String productId;
  const _HeartButton({required this.size, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final saved = authUser == null
        ? false
        : (ref.watch(userFavoriteProductIdsProvider(authUser.uid)).valueOrNull ??
                const <String>{})
            .contains(productId);

    return GestureDetector(
      onTap: () async {
        if (authUser == null) {
          ScaffoldMessenger.of(context).clearSnackBars();
          showSignInRequiredSheet(context);
          return;
        }
        try {
          await ref.read(favoriteRepositoryProvider).toggle(
                userId: authUser.uid,
                targetType: 'product',
                targetId: productId,
              );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update favorite: $e')),
            );
          }
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(size == 24 ? 6 : 8),
        ),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? AppColors.red : AppColors.text4,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _down ? 0.965 : 1.0,
        child: widget.child,
      ),
    );
  }
}
