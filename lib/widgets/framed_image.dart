import 'dart:ui';

import 'package:flutter/material.dart';
import 'cached_image.dart';

/// Displays [imageUrl] on a self-generated blurred backdrop of the SAME
/// image, so every product photo — square, portrait, or a legacy
/// landscape shot from any device — presents as one consistent, polished
/// framed canvas WITHOUT ever cropping the product.
///
/// Why this and not AI outpainting: the empty border space is filled with
/// a soft, darkened, zoomed copy of the image itself (the treatment
/// Spotify / Apple Music use behind album art). It's a free on-device GPU
/// blur — no AI service, no per-image cost, no network round-trip (the
/// duplicate [CachedImage] resolves from cache, so the photo downloads
/// once), and it can never hallucinate wrong content onto a product shot
/// the way a generative fill could. New uploads are already centre-cropped
/// to a square by the image processor, so for those the backdrop is barely
/// visible; for older non-square images it quietly fills the bars.
class FramedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  /// Blur strength for the backdrop. The default reads as a soft wash,
  /// not a recognisable second copy of the image.
  final double blurSigma;

  const FramedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.blurSigma = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          color: const Color(0xFFF5F5F5),
          child: Icon(Icons.shopping_bag_outlined,
              size: 48, color: Colors.grey.shade400),
        ),
      );
    }
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred, slightly zoomed cover backdrop fills the frame
            // edge to edge. The scale hides the transparent bleed a blur
            // leaves around the image border.
            ImageFiltered(
              imageFilter:
                  ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Transform.scale(
                scale: 1.18,
                child: CachedImage(
                  imageUrl: imageUrl,
                  width: width,
                  height: height,
                ),
              ),
            ),
            // Gentle scrim so a busy backdrop never competes with the
            // product sitting on top of it.
            Container(color: Colors.black.withValues(alpha: 0.10)),
            // The actual product — contained, never cropped.
            CachedImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
