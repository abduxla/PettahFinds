import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;

  const CachedImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(placeholderIcon,
          size: 40, color: Theme.of(context).colorScheme.outline),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: placeholder,
      );
    }

    // Decode the bitmap at roughly the on-screen pixel size instead of
    // its full Storage resolution. Cuts memory by 5–20× on grid screens.
    // Falls back to a sane default if neither dimension is provided.
    // Guards against `double.infinity` (callers commonly pass that for
    // banner-style fills) — `infinity.round()` throws.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    int? scale(double? v) =>
        (v != null && v.isFinite) ? (v * dpr).round() : null;
    final memCacheH = scale(height) ?? scale(width) ?? 720;
    final memCacheW = scale(width) ?? scale(height) ?? 720;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheHeight: memCacheH,
        memCacheWidth: memCacheW,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
