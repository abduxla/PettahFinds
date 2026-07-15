import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Target dimensions for all product images after processing.
const _kTargetSize = 1200;

/// JPEG quality after resize. 88 preserves visually lossless detail for
/// marketplace product photos while keeping files comfortably under 500 KB.
const _kJpegQuality = 88;

/// Process a raw image captured from the camera or picked from the gallery.
///
/// Pipeline (runs in a separate isolate via [compute]):
/// 1. Read bytes from [sourcePath].
/// 2. Decode (JPEG / PNG / WebP / BMP accepted).
/// 3. Correct EXIF orientation so portrait camera shots aren't sideways.
/// 4. Center-crop to square (largest square from the center).
/// 5. Resize to [_kTargetSize] × [_kTargetSize] px.
/// 6. Re-encode as JPEG at [_kJpegQuality]%.
///
/// Returns the processed JPEG bytes ready for [StorageService.uploadBytes].
Future<Uint8List> processProductImage(String sourcePath) {
  return compute(_processIsolate, sourcePath);
}

/// Top-level so [compute] can serialize the function reference.
Future<Uint8List> _processIsolate(String sourcePath) async {
  final raw = await File(sourcePath).readAsBytes();

  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Could not read image file. Please try a different photo.');
  }

  // Rotate to match EXIF orientation so camera photos aren't sideways.
  final oriented = img.bakeOrientation(decoded);

  // Center-crop to the largest possible square.
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  final cropX = (oriented.width - side) ~/ 2;
  final cropY = (oriented.height - side) ~/ 2;
  final cropped = img.copyCrop(oriented, x: cropX, y: cropY, width: side, height: side);

  // Resize to target dimensions.
  final resized = img.copyResize(
    cropped,
    width: _kTargetSize,
    height: _kTargetSize,
    interpolation: img.Interpolation.linear,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: _kJpegQuality));
}
