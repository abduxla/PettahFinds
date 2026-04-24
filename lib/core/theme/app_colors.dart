import 'package:flutter/material.dart';

/// Design-system colour tokens — per the PetaFinds UI Spec v1.0.
/// Reference: `PetaFinds-Design-Spec.pdf`.
///
/// Use these constants everywhere — no hardcoded hex values on any
/// screen that follows the spec.
class AppColors {
  // ---- Backgrounds ----
  static const Color bg         = Color(0xFFFAFAF8);
  static const Color bgSection  = Color(0xFFF2F2EF);
  static const Color white      = Color(0xFFFFFFFF);

  // ---- Brand ----
  static const Color teal       = Color(0xFF0D6E6E);
  static const Color tealDark   = Color(0xFF095858);
  static const Color tealLight  = Color(0xFFE8F4F4);

  // ---- Accents ----
  static const Color orange     = Color(0xFFE8821A);
  static const Color red        = Color(0xFFD63B3B);

  // ---- Text ----
  static const Color text1      = Color(0xFF111110);
  static const Color text2      = Color(0xFF3D3D3A);
  static const Color text3      = Color(0xFF78786E);
  static const Color text4      = Color(0xFFAEAEA4);

  // ---- Borders ----
  static const Color border     = Color(0xFFE8E8E4);

  // ---- Back-compat aliases (used in a few leftover call-sites) ----
  /// Alias for `bg`. Present so older screens keep compiling.
  static const Color surface = bg;
  /// Alias for `white`.
  static const Color surfaceContainerLowest = white;
  /// Alias for `bgSection`.
  static const Color surfaceContainer = bgSection;
  /// Alias for `bgSection`.
  static const Color surfaceContainerLow = bgSection;
  /// Alias for `bgSection`.
  static const Color surfaceContainerHigh = bgSection;
  /// Alias for `border`.
  static const Color surfaceVariant = border;
  /// Alias for `border`.
  static const Color outlineVariant = border;
  /// Alias for `text2`.
  static const Color onSurface = text1;
  /// Alias for `text2`.
  static const Color onSurfaceVariant = text2;
  /// Alias for `text3`.
  static const Color outline = text3;
  /// Alias for `teal` — kept for leftover code still reading `primary`.
  static const Color primary = teal;
  /// Alias for `teal`.
  static const Color primaryContainer = teal;
  /// Alias for `tealLight`.
  static const Color primaryTint = tealLight;
  /// Alias for `orange`.
  static const Color secondaryContainer = orange;
}
