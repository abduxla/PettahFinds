import 'package:flutter/material.dart';

/// Global brightness that [AppColors] resolves against.
///
/// The app keeps this in sync with the active [ThemeData] (set once per
/// root build in `main.dart`). Because every [AppColors] token is a getter
/// that reads this flag, flipping it + rebuilding the tree (which a
/// themeMode change does) re-themes every screen — including the ~hundreds
/// of hand-coded `AppColors.x` call-sites — with no per-site changes.
///
/// Dark mode is offered to guests / users / businesses; admins are always
/// light (enforced where this is set).
Brightness appBrightness = Brightness.light;

bool get _isDark => appBrightness == Brightness.dark;

/// A complete colour set for one brightness. Two const instances below
/// ([_light], [_dark]); [AppColors] picks between them at read time.
class _Palette {
  final Color bg;
  final Color bgSection;
  final Color white; // "surface" — cards / sheets (elevated above scaffold)
  final Color teal;
  final Color tealDark;
  final Color tealLight;
  final Color orange;
  final Color red;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color border;

  const _Palette({
    required this.bg,
    required this.bgSection,
    required this.white,
    required this.teal,
    required this.tealDark,
    required this.tealLight,
    required this.orange,
    required this.red,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.border,
  });
}

const _Palette _light = _Palette(
  bg: Color(0xFFFAFAF8),
  bgSection: Color(0xFFF2F2EF),
  white: Color(0xFFFFFFFF),
  teal: Color(0xFF0D6E6E),
  tealDark: Color(0xFF095858),
  tealLight: Color(0xFFE8F4F4),
  orange: Color(0xFFE8821A),
  red: Color(0xFFD63B3B),
  text1: Color(0xFF111110),
  text2: Color(0xFF3D3D3A),
  text3: Color(0xFF78786E),
  text4: Color(0xFFAEAEA4),
  border: Color(0xFFE8E8E4),
);

/// Warm-neutral dark with the same teal/orange brand pops, tuned for
/// legibility on a near-black canvas. Card ("white") sits a step above the
/// scaffold ("bgSection") so the existing card-on-section depth survives.
const _Palette _dark = _Palette(
  bg: Color(0xFF0E0F11),
  bgSection: Color(0xFF121316),
  white: Color(0xFF1C1E22),
  teal: Color(0xFF22A39F),
  tealDark: Color(0xFF1B8583),
  tealLight: Color(0xFF12302F),
  orange: Color(0xFFF0913A),
  red: Color(0xFFF06B6B),
  text1: Color(0xFFF3F3F1),
  text2: Color(0xFFC7C7C2),
  text3: Color(0xFF98988F),
  text4: Color(0xFF6B6B64),
  border: Color(0xFF2B2D32),
);

_Palette get _p => _isDark ? _dark : _light;

/// Design-system colour tokens — per the PetaFinds UI Spec v1.0.
/// Reference: `PetaFinds-Design-Spec.pdf`.
///
/// Use these everywhere — no hardcoded hex values on screens that follow
/// the spec. Tokens are brightness-aware getters (see [appBrightness]);
/// they cannot be used in `const` expressions.
class AppColors {
  // ---- Backgrounds ----
  static Color get bg => _p.bg;
  static Color get bgSection => _p.bgSection;
  static Color get white => _p.white;

  // ---- Brand ----
  static Color get teal => _p.teal;
  static Color get tealDark => _p.tealDark;
  static Color get tealLight => _p.tealLight;

  // ---- Accents ----
  static Color get orange => _p.orange;
  static Color get red => _p.red;

  // ---- Text ----
  static Color get text1 => _p.text1;
  static Color get text2 => _p.text2;
  static Color get text3 => _p.text3;
  static Color get text4 => _p.text4;

  // ---- Borders ----
  static Color get border => _p.border;

  // ---- Back-compat aliases (used in a few leftover call-sites) ----
  static Color get surface => bg;
  static Color get surfaceContainerLowest => white;
  static Color get surfaceContainer => bgSection;
  static Color get surfaceContainerLow => bgSection;
  static Color get surfaceContainerHigh => bgSection;
  static Color get surfaceVariant => border;
  static Color get outlineVariant => border;
  static Color get onSurface => text1;
  static Color get onSurfaceVariant => text2;
  static Color get outline => text3;
  static Color get primary => teal;
  static Color get primaryContainer => teal;
  static Color get primaryTint => tealLight;
  static Color get secondaryContainer => orange;
}
