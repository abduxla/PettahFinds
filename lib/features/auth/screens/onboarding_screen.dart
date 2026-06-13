import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

/// Marks first-run onboarding as complete; the splash screen reads this
/// flag to decide whether to send the user through onboarding again.
const String onboardingCompletedKey = 'onboarding_completed_v1';

// Brand teal gradient — mirrors the home "Pettah, Now Digital" card so
// onboarding feels like the same app. Deep teal at the top easing into a
// brighter teal at the bottom.
const _gTop = Color(0xFF0A4A4A);
const _gMid = Color(0xFF0D6E6E);
const _gBottom = Color(0xFF13807E);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _accepted = false;
  bool _finishing = false;
  String? _finishingRole;

  static const _totalPages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishAs(String role) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _finishingRole = role;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
    if (!mounted) return;
    if (role == 'business') {
      context.go('/sign-in');
    } else {
      context.go('/home');
    }
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _gTop,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _gBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _gTop,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_gTop, _gMid, _gBottom],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ---- Top bar: Skip on slides 0/1 ----
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _totalPages - 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: TextButton(
                            onPressed: _skip,
                            child: Text(
                              'Skip',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ---- Pages ----
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: const [
                      _HeroSlide(
                        icon: Icons.travel_explore_rounded,
                        eyebrow: '📍  PETTAH · COLOMBO 11',
                        line1: 'Thousands of shops\nin Pettah.',
                        line2: 'No way to find them.',
                        subtitle:
                            'Street by street. Shop by shop. Sound familiar?',
                      ),
                      _HeroSlide(
                        icon: Icons.search_rounded,
                        eyebrow: '✨  THE PETAFINDS WAY',
                        line1: 'Every shop in Pettah.',
                        line2: 'One search.',
                        subtitle:
                            'Photos, prices, and the exact street — before you leave home.',
                      ),
                      _BrandSlide(),
                    ],
                  ),
                ),

                // ---- Slide 3: terms checkbox ----
                if (_currentPage == _totalPages - 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                    child: _TermsCheckbox(
                      accepted: _accepted,
                      onChanged: (v) =>
                          setState(() => _accepted = v ?? false),
                    ),
                  ),

                // ---- Dots ----
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.orange
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // ---- CTA ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: _currentPage == _totalPages - 1
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CtaButton(
                              label: 'Continue as Customer',
                              background: Colors.white,
                              foreground: _gMid,
                              loading: _finishing && _finishingRole == 'user',
                              onPressed: (_accepted && !_finishing)
                                  ? () => _finishAs('user')
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _CtaButton(
                              label: 'Continue as Business',
                              background: AppColors.orange,
                              foreground: Colors.white,
                              loading:
                                  _finishing && _finishingRole == 'business',
                              onPressed: (_accepted && !_finishing)
                                  ? () => _finishAs('business')
                                  : null,
                            ),
                          ],
                        )
                      : _CtaButton(
                          label: 'Continue  →',
                          background: Colors.white,
                          foreground: _gMid,
                          onPressed: _next,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CTA button — pill, used for next + the two role buttons
// ============================================================
class _CtaButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool loading;
  final VoidCallback? onPressed;
  const _CtaButton({
    required this.label,
    required this.background,
    required this.foreground,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.4),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: foreground),
              )
            : Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}

// ============================================================
// HERO SLIDE (slides 1 & 2) — glass icon + headline + subtitle
// ============================================================
class _HeroSlide extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String line1;
  final String line2;
  final String subtitle;
  const _HeroSlide({
    required this.icon,
    required this.eyebrow,
    required this.line1,
    required this.line2,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glass icon tile with a soft orange glow.
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.28),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 54, color: Colors.white),
          ),
          const SizedBox(height: 34),
          _EyebrowPill(text: eyebrow),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              line1,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.12,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              line2,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.orange,
                letterSpacing: -0.8,
                height: 1.12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EyebrowPill extends StatelessWidget {
  final String text;
  const _EyebrowPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ============================================================
// BRAND SLIDE (slide 3) — logo + value prop + glass benefits
// ============================================================
class _BrandSlide extends StatelessWidget {
  const _BrandSlide();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // App icon — white tile with the brand P + orange magnifier.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.3),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'P',
                    style: GoogleFonts.nunito(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: _gMid,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: _gTop, width: 2.5),
                  ),
                  child: const Icon(Icons.search, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PetaFinds',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.6,
                  )),
              Padding(
                padding: const EdgeInsets.only(left: 3, bottom: 7),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8821A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("Colombo's wholesale marketplace",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: Colors.white.withValues(alpha: 0.75),
              )),
          const SizedBox(height: 22),

          // Glass benefits card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: const [
                _BenefitRow(
                  icon: Icons.search,
                  title: 'Search any product',
                  subtitle: 'Find it across all of Pettah instantly',
                ),
                _BenefitDivider(),
                _BenefitRow(
                  icon: Icons.storefront_outlined,
                  title: 'See every seller',
                  subtitle: 'Compare prices before you visit',
                ),
                _BenefitDivider(),
                _BenefitRow(
                  icon: Icons.location_on_outlined,
                  title: 'Know the exact street',
                  subtitle: 'Go straight to the right shop',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(
            height: 1, color: Colors.white.withValues(alpha: 0.12)),
      );
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BenefitRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.nunito(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  const _TermsCheckbox({required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.dmSans(
      fontSize: 12.5,
      color: Colors.white.withValues(alpha: 0.85),
      height: 1.4,
    );
    final link = GoogleFonts.dmSans(
      fontSize: 12.5,
      color: Colors.white,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      height: 1.4,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: accepted,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeColor: AppColors.orange,
          checkColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                const TextSpan(text: 'I agree to the PetaFinds '),
                TextSpan(
                  text: 'Terms of Use',
                  style: link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/legal/user-terms'),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/legal/privacy'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
