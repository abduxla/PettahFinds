import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/business.dart';
import '../../../models/favorite.dart';
import '../../../models/product.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/sign_in_required.dart';

final _userFavoritesProvider =
    StreamProvider.autoDispose.family<List<Favorite>, String>((ref, uid) {
  return ref.watch(favoriteRepositoryProvider).streamByUser(uid);
});

/// Resolve a single favorite target (product or business) — safe against
/// deleted docs (returns null on error so the row renders a placeholder).
/// Soft-deleted products (`isActive == false`) also resolve to null so
/// users don't tap through to the "no longer available" detail screen.
final _favoriteTargetProvider =
    FutureProvider.autoDispose.family<Object?, Favorite>((ref, fav) async {
  try {
    if (fav.targetType == 'business') {
      return await ref.watch(businessRepositoryProvider).getById(fav.targetId);
    }
    final product =
        await ref.watch(productRepositoryProvider).getById(fav.targetId);
    return product.isActive ? product : null;
  } catch (_) {
    return null;
  }
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    // Auth loading → short-lived spinner.
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgSection,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    // Guest → sign-in prompt.
    if (authState.valueOrNull == null) {
      return Scaffold(
        backgroundColor: AppColors.bgSection,
        appBar: AppBar(
          title: Text(
            'Favorites',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text1,
            ),
          ),
        ),
        body: const SignInRequired(
          icon: Icons.favorite_outline,
          title: 'Save items you love',
          subtitle:
              'Sign in to favourite products and businesses and pick them up where you left off.',
        ),
      );
    }

    if (appUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgSection,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final favoritesAsync = ref.watch(_userFavoritesProvider(appUser.uid));

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text1,
          ),
        ),
      ),
      body: favoritesAsync.when(
        data: (favorites) => favorites.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                itemCount: favorites.length,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _FavoriteTile(
                  favorite: favorites[i],
                  userId: appUser.uid,
                ),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_userFavoritesProvider(appUser.uid)),
        ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  final Favorite favorite;
  final String userId;
  const _FavoriteTile({required this.favorite, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(_favoriteTargetProvider(favorite));
    final target = targetAsync.valueOrNull;

    // Loading: shimmer placeholder.
    if (targetAsync.isLoading) {
      return Container(
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      );
    }

    // Target missing/deleted — render minimal row with remove action.
    if (target == null) {
      return _BaseTile(
        title: favorite.targetType == 'business'
            ? 'Business unavailable'
            : 'Product unavailable',
        subtitle: 'This item may have been removed',
        icon: favorite.targetType == 'business'
            ? Icons.store_outlined
            : Icons.shopping_bag_outlined,
        onRemove: () => ref.read(favoriteRepositoryProvider).toggle(
              userId: userId,
              targetType: favorite.targetType,
              targetId: favorite.targetId,
            ),
        onTap: null,
      );
    }

    if (favorite.targetType == 'business' && target is Business) {
      return _BusinessFavTile(
        business: target,
        onRemove: () => ref.read(favoriteRepositoryProvider).toggle(
              userId: userId,
              targetType: 'business',
              targetId: favorite.targetId,
            ),
      );
    }

    if (target is Product) {
      return _ProductFavTile(
        product: target,
        onRemove: () => ref.read(favoriteRepositoryProvider).toggle(
              userId: userId,
              targetType: 'product',
              targetId: favorite.targetId,
            ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ProductFavTile extends StatelessWidget {
  final Product product;
  final VoidCallback onRemove;
  const _ProductFavTile({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      onTap: () => context.go('/home/product/${product.id}'),
      onRemove: onRemove,
      leadingImage: product.image1Url,
      fallbackIcon: Icons.shopping_bag_outlined,
      typeLabel: 'PRODUCT',
      title: product.title,
      subtitle: 'LKR ${_fmtPrice(product.priceLkr)}',
      subtitleColor: AppColors.teal,
      subtitleWeight: FontWeight.w800,
      subtitleFont: 'nunito',
    );
  }
}

class _BusinessFavTile extends StatelessWidget {
  final Business business;
  final VoidCallback onRemove;
  const _BusinessFavTile({required this.business, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      onTap: () => context.go('/home/business/${business.id}'),
      onRemove: onRemove,
      leadingImage: business.logoUrl,
      fallbackIcon: Icons.store_outlined,
      typeLabel: 'BUSINESS',
      title: business.businessName,
      subtitle: business.location.isNotEmpty
          ? business.location
          : business.category,
      verified: business.isVerified,
    );
  }
}

class _BaseTile extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback onRemove;
  final String? leadingImage;
  final IconData? fallbackIcon;
  final IconData? icon;
  final String? typeLabel;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final FontWeight? subtitleWeight;
  final String? subtitleFont;
  final bool verified;
  const _BaseTile({
    required this.onTap,
    required this.onRemove,
    required this.title,
    required this.subtitle,
    this.leadingImage,
    this.fallbackIcon,
    this.icon,
    this.typeLabel,
    this.subtitleColor,
    this.subtitleWeight,
    this.subtitleFont,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    final subStyle = subtitleFont == 'nunito'
        ? GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: subtitleWeight ?? FontWeight.w500,
            color: subtitleColor ?? AppColors.text2,
          )
        : GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: subtitleWeight ?? FontWeight.w500,
            color: subtitleColor ?? AppColors.text3,
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Leading image / icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.bgSection,
                child: leadingImage != null && leadingImage!.isNotEmpty
                    ? CachedImage(
                        imageUrl: leadingImage!,
                        width: 64,
                        height: 64,
                        placeholderIcon:
                            fallbackIcon ?? Icons.image_outlined,
                      )
                    : Icon(
                        icon ?? fallbackIcon ?? Icons.favorite_outline,
                        color: AppColors.text4,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (typeLabel != null)
                    Text(
                      typeLabel!,
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text4,
                        letterSpacing: 0.8,
                      ),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 14, color: AppColors.teal),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subStyle,
                  ),
                ],
              ),
            ),
            // Clear favorited heart with remove action.
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.favorite, color: AppColors.red),
              tooltip: 'Remove from favorites',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_outline,
                  color: AppColors.teal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any product or business to save it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtPrice(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
