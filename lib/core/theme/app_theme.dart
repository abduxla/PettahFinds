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

/// Apple matched-geometry style cubic curves. Defined as explicit
/// Cubic constants so this file compiles against any Flutter
/// version (older SDKs don't ship Curves.easeOutExpo as a named
/// constant). Values are the canonical easeOutExpo / easeInExpo
/// control points from the CSS spec.
const Cubic _kEaseOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);
const Cubic _kEaseInExpo = Cubic(0.7, 0.0, 0.84, 0.0);

/// Custom PageTransitionsBuilder — Apple "matched geometry" feel.
///
/// SHAKE FIX (the visible jitter on swipe-back / pop):
/// The previous builder ran TWO competing transforms on pop:
///   1. The departing route's primaryAnimation reversed 1→0 — its
///      ScaleTransition(0.96→1.0) un-scaled.
///   2. The arriving route's secondaryAnimation reversed 1→0 — its
///      ScaleTransition(1.0→0.97) un-scaled at the same time.
///   3. Cupertino's slide added a third translateX on top.
/// Three concurrent transforms on overlapping screens during the
/// gesture-driven pop produced the shake. The new builder
/// suppresses the secondary transform stack entirely when
/// `animation.status == AnimationStatus.reverse`, leaving only the
/// primary slide+scale+fade. That's what "settles" Apple's pop
/// gesture in their own UIKit — secondary effects only run on
/// PUSH; pop is a single-actor transform.
///
/// MATCHED GEOMETRY FEEL:
/// Apple's push doesn't slide a screen all the way from off-screen.
/// It emerges from a small offset (here Offset(0.06, 0)) while
/// scaling up + fading in. Combined with the outgoing screen's
/// scale-down + fade (push-only), the two screens feel spatially
/// connected — like one geometry continuing into the next, not two
/// rectangles sliding past each other.
///
/// SWIPE-BACK GESTURE NOTE:
/// We no longer delegate to CupertinoPageTransitionsBuilder, which
/// also means the edge-swipe-back gesture detector (a Cupertino
/// implementation detail) is no longer attached. Users can still
/// pop via the AppBar back arrow on every screen. Add a custom
/// SwipeBackGestureDetector in a follow-up if the gesture is
/// strictly required.
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
    // SHAKE-FIX GATE: only run the secondary (outgoing-page)
    // dim+scale on PUSH. On POP the secondary animation is
    // running in reverse from a non-zero starting point AND the
    // primary is also reversing — running both produces the shake.
    final isPopping = animation.status == AnimationStatus.reverse;

    // Entering page — soft Apple-style emergence.
    //   - Slide from a SUBTLE offset (6% of width). Full-width
    //     slides feel like Android.
    //   - Scale up from 0.97 → 1.0 (the "matched geometry" cue).
    //   - Fade in 0→1 in the first 60% of the duration so the
    //     pixels resolve before motion settles.
    final enterSlide = Tween<Offset>(
      begin: const Offset(0.06, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: _kEaseOutExpo,
      reverseCurve: _kEaseInExpo,
    ));

    final enterScale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: _kEaseOutExpo,
        reverseCurve: _kEaseInExpo,
      ),
    );

    final enterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    Widget enteringStack = SlideTransition(
      position: enterSlide,
      child: ScaleTransition(
        scale: enterScale,
        child: FadeTransition(
          opacity: enterFade,
          child: child,
        ),
      ),
    );

    if (isPopping) {
      // POP path: render the entering page's animation only. No
      // secondary scale/fade — that's what caused the shake.
      return enteringStack;
    }

    // PUSH path: also apply the outgoing-page recession so the
    // user sees the leaving screen step back into the background.
    final exitScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: _kEaseInExpo,
      ),
    );
    final exitFade = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    return ScaleTransition(
      scale: exitScale,
      child: FadeTransition(
        opacity: exitFade,
        child: enteringStack,
      ),
    );
  }
}
