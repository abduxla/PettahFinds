import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// App-wide theme. Colours come from [AppColors] (the design system).
/// Typography: DM Sans for body / UI text, Nunito w800+ for display-weight
/// headings — matches the home-screen redesign and propagates to every
/// screen that uses Theme.of(context).
///
/// AppTheme.* legacy constants are kept as aliases for the 3 call-sites
/// that still reference them directly (main.dart, search, map).
abstract class AppTheme {
  // --- Legacy aliases, remapped to the new palette ---
  static const accent       = AppColors.teal;
  static const accentDark   = AppColors.tealDark;
  static const accentLight  = AppColors.tealLight;
  static const accentCool   = Color(0xFFA9B9C9);
  static const bg           = AppColors.bgSection;
  static const bgAlt        = AppColors.bg;
  static const inputBg      = AppColors.white;
  static const card         = AppColors.white;
  static const text         = AppColors.text1;
  static const textSub      = AppColors.text2;
  static const textMuted    = AppColors.text4;
  static const border       = AppColors.border;
  static const success      = Color(0xFF22C55E);

  static ThemeData get light {
    final cs = ColorScheme.light(
      primary: AppColors.teal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tealLight,
      onPrimaryContainer: AppColors.tealDark,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      surface: AppColors.white,
      onSurface: AppColors.text1,
      error: AppColors.red,
      outline: AppColors.text4,
      surfaceContainerHighest: AppColors.bgSection,
    );

    // Base text theme: DM Sans for everything by default. Headlines
    // (display/headline) get Nunito w800/w900 so section titles and big
    // numbers read as the brand font.
    final dmSansBase = GoogleFonts.dmSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );
    final textTheme = dmSansBase.copyWith(
      displayLarge: GoogleFonts.nunito(
          fontSize: 32, fontWeight: FontWeight.w900,
          color: AppColors.text1, letterSpacing: -0.8),
      displayMedium: GoogleFonts.nunito(
          fontSize: 28, fontWeight: FontWeight.w900,
          color: AppColors.text1, letterSpacing: -0.6),
      displaySmall: GoogleFonts.nunito(
          fontSize: 24, fontWeight: FontWeight.w800,
          color: AppColors.text1, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.nunito(
          fontSize: 22, fontWeight: FontWeight.w800,
          color: AppColors.text1, letterSpacing: -0.4),
      headlineMedium: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: AppColors.text1, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: AppColors.text1, letterSpacing: -0.2),
      titleLarge: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.text1, letterSpacing: -0.2),
      titleMedium: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: AppColors.text1),
      titleSmall: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.text2),
      bodyLarge: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: AppColors.text2, height: 1.45),
      bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: AppColors.text2, height: 1.45),
      bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: AppColors.text3, height: 1.4),
      labelLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: AppColors.text1, letterSpacing: 0),
      labelMedium: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.text2),
      labelSmall: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: AppColors.text3),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.bgSection,
      textTheme: textTheme,
      fontFamily: GoogleFonts.dmSans().fontFamily,

      // Snappy iOS-style page transitions on every platform.
      // [_PremiumSlideTransitionsBuilder] front-loads the route's
      // animation with Curves.fastEaseInToSlowEaseOut before handing
      // off to the standard Cupertino implementation, so the slide
      // reaches ~80% complete in the first 60% of the duration. Net
      // effect: feels markedly snappier WITHOUT shortening the route
      // duration (which would break the edge-swipe-back gesture). The
      // gesture detector is preserved because we delegate the actual
      // build to CupertinoPageTransitionsBuilder.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _PremiumSlideTransitionsBuilder(),
          TargetPlatform.iOS: _PremiumSlideTransitionsBuilder(),
          TargetPlatform.macOS: _PremiumSlideTransitionsBuilder(),
          TargetPlatform.linux: _PremiumSlideTransitionsBuilder(),
          TargetPlatform.windows: _PremiumSlideTransitionsBuilder(),
          TargetPlatform.fuchsia: _PremiumSlideTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bgSection,
        foregroundColor: AppColors.text1,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.nunito(
          color: AppColors.text1,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.text1, size: 22),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.dmSans(
            color: AppColors.text4,
            fontSize: 14,
            fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.dmSans(
            color: AppColors.text3,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.dmSans(
            color: AppColors.teal,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: AppColors.text1,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: AppColors.tealLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.teal : AppColors.text4,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.teal : AppColors.text4,
          );
        }),
      ),

      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 0),

      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: AppColors.text1),
        subtitleTextStyle: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w400,
            color: AppColors.text3),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bg,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.text1,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        actionTextColor: AppColors.orange,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.nunito(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: AppColors.text1, letterSpacing: -0.2),
        contentTextStyle: GoogleFonts.dmSans(
            fontSize: 14, color: AppColors.text2, height: 1.45),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.teal : AppColors.white),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.text1),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.teal : const Color(0xFFD1D5DB)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 8,
        textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.text1,
            fontWeight: FontWeight.w500),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.text3,
        indicatorColor: AppColors.teal,
        labelStyle: GoogleFonts.dmSans(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Custom PageTransitionsBuilder — Temu-style premium feel.
///
/// PHILOSOPHY
/// Snappy but never bouncy. The incoming page slides in from the
/// right AND scales up subtly (0.96 → 1.0) for a "stepping forward"
/// sensation. The outgoing page (when a new route pushes on top)
/// recedes slightly via scale-down + fade so the screen the user is
/// leaving feels like it's settling into the background.
///
/// LAYERING
/// Three composed transitions:
///   1. Slide (handled by CupertinoPageTransitionsBuilder so the
///      edge-swipe-back gesture detector stays attached).
///   2. Scale-up on enter — 0.96 → 1.0, easeOutCubic.
///   3. Scale-down + fade on the outgoing page when something new
///      pushes on top — 1.0 → 0.97 scale, 1.0 → 0.88 fade,
///      easeInCubic.
///
/// REVERSE / POP
/// CurvedAnimation's `reverseCurve` is set explicitly so push and pop
/// both feel right. On pop the entering page (the one underneath
/// coming back to the front) un-scales from 0.97 → 1.0 and un-fades
/// from 0.88 → 1.0 via easeOutCubic. The departing page (the one
/// being popped off) un-scales from 1.0 → 0.96 and slides out to the
/// right via the inverse Cupertino slide.
///
/// DURATION
/// Inherited from each route's `transitionDuration`. MaterialPage
/// (the default Page<T> go_router uses) is 300ms — already inside
/// the Temu 280–320ms window the spec asks for. No global override
/// needed.
class _PremiumSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming-page curve. easeOutCubic on the forward direction is
    // "starts fast, settles" — the snappy-but-not-bouncy feeling.
    // reverseCurve flips to easeInCubic so the pop animation has the
    // same "expensive" pacing in reverse (slow start, fast finish on
    // exit).
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Outgoing-page curve. easeInCubic on the forward direction means
    // the receding page accelerates as it leaves — gives the "stepping
    // back" feeling without lingering.
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInCubic,
      reverseCurve: Curves.easeOutCubic,
    );

    // Compose: outermost wrap is the exit scale+fade on the outgoing
    // page, then the enter scale, then the Cupertino slide. The
    // gesture detector lives inside the Cupertino layer.
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.97).animate(exit),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.88).animate(exit),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(enter),
          child: const CupertinoPageTransitionsBuilder().buildTransitions<T>(
            route,
            context,
            animation,
            secondaryAnimation,
            child,
          ),
        ),
      ),
    );
  }
}
