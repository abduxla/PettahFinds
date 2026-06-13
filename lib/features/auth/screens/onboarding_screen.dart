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
        statusBarColor: AppColors.bg,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
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
                              color: AppColors.text3,
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
                    _SlideOne(),
                    _SlideTwo(),
                    _SlideThree(),
                  ],
                ),
              ),

              // ---- Slide 3: terms checkbox ----
              if (_currentPage == _totalPages - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: _TermsCheckbox(
                    accepted: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
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
                            : AppColors.border,
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
                          SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.teal.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              onPressed: (_accepted && !_finishing)
                                  ? () => _finishAs('user')
                                  : null,
                              child: _finishing && _finishingRole == 'user'
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white))
                                  : Text(
                                      'Continue as Customer',
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.orange.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              onPressed: (_accepted && !_finishing)
                                  ? () => _finishAs('business')
                                  : null,
                              child: _finishing && _finishingRole == 'business'
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white))
                                  : Text(
                                      'Continue as Business',
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _next,
                          child: Text(
                            'Continue  →',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SLIDE 1
// ============================================================
class _SlideOne extends StatelessWidget {
  const _SlideOne();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Map mock card — flex-based so it shrinks on small screens
          Expanded(
            flex: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.95,
                child: _MapMockCard(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OrangePill(text: '📍  PETTAH · COLOMBO 11'),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Thousands of shops in\nPettah.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.text1,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'No way to find them.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.orange,
                letterSpacing: -0.6,
                height: 1.15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Street by street. Shop by shop. Sound familiar?',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: AppColors.text3,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MapMockCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gridLine = AppColors.border;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Faint grid lines
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter(color: gridLine)),
          ),
          // Street labels
          Positioned(
            top: 18,
            right: 14,
            child: Text('Sea St.',
                style: GoogleFonts.dmSans(
                  fontSize: 9.5,
                  color: AppColors.text4,
                )),
          ),
          Positioned(
            top: 80,
            left: 12,
            child: Text('4th Cross',
                style: GoogleFonts.dmSans(
                  fontSize: 9.5,
                  color: AppColors.text4,
                )),
          ),
          Positioned(
            bottom: 30,
            left: 14,
            child: Text('Front St.',
                style: GoogleFonts.dmSans(
                  fontSize: 9.5,
                  color: AppColors.text4,
                )),
          ),

          // Shop pills row 1
          const Positioned(
            top: 36,
            left: 28,
            child: _ShopChip(emoji: '🥥'),
          ),
          const Positioned(
            top: 36,
            left: 78,
            child: _ShopChip(emoji: '🌿'),
          ),
          const Positioned(
            top: 36,
            right: 22,
            child: _ShopChip(emoji: '🧮', label: 'LKR 450'),
          ),

          // Row 2
          const Positioned(
            top: 100,
            left: 22,
            child: _ShopChip(emoji: '⏳', label: 'No stock'),
          ),
          const Positioned(
            top: 100,
            right: 64,
            child: _ShopChip(emoji: '💎'),
          ),
          const Positioned(
            top: 100,
            right: 18,
            child: _ShopChip(emoji: '🌶️'),
          ),

          // Row 3 (lost shopper + question mark)
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgSection,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '?',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('🚶', style: TextStyle(fontSize: 26)),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 158,
            left: 30,
            child: _ShopChip(emoji: '', label: 'Try next\nstreet'),
          ),

          // Row 4
          const Positioned(
            bottom: 56,
            left: 60,
            child: _ShopChip(emoji: '🧴'),
          ),
          const Positioned(
            bottom: 56,
            left: 110,
            child: _ShopChip(emoji: '🪙'),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    // Horizontal lines
    for (double y = 22; y < size.height; y += 36) {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
        x += dashWidth + dashSpace;
      }
    }
    // Vertical lines
    for (double x = 22; x < size.width; x += 36) {
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dashWidth), paint);
        y += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ShopChip extends StatelessWidget {
  final String emoji;
  final String? label;
  const _ShopChip({required this.emoji, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: label != null ? 8 : 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text1.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) Text(emoji, style: const TextStyle(fontSize: 14)),
          if (label != null) ...[
            if (emoji.isNotEmpty) const SizedBox(width: 5),
            Text(
              label!,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text2,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrangePill extends StatelessWidget {
  final String text;
  const _OrangePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.orange,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ============================================================
// SLIDE 2
// ============================================================
class _SlideTwo extends StatelessWidget {
  const _SlideTwo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(flex: 5, child: Center(child: _SearchMockCard())),
          const SizedBox(height: 12),
          _OrangePill(text: '+ THE PETAFINDS WAY'),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Every shop in\nPettah.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.text1,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'One search.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.orange,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Photos, prices, and the exact street — before you leave home.',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: AppColors.text3,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SearchMockCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text1.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.bgSection,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search,
                    size: 18, color: AppColors.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('iphone charger |',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.text1,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Search',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('3 sellers found in Pettah',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w600,
                )),
          ),
          const SizedBox(height: 8),
          _SellerRow(
              emoji: '📱',
              name: 'Mobile Centre',
              price: 'LKR 1,900',
              tag: '3rd Cross'),
          const SizedBox(height: 6),
          _SellerRow(
              emoji: '⚡',
              name: 'Charger House Pettah',
              price: 'LKR 2,500',
              tag: 'Sea Street'),
          const SizedBox(height: 6),
          _SellerRow(
              emoji: '🔌',
              name: 'Tech Lanka Trading',
              price: 'LKR 3,200',
              tag: 'Front St.'),
        ],
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final String tag;
  const _SellerRow(
      {required this.emoji,
      required this.name,
      required this.price,
      required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSection,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.tealLight,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text1,
                    )),
                Text(price,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orange,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(tag,
                style: GoogleFonts.dmSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text2,
                )),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SLIDE 3
// ============================================================
class _SlideThree extends StatelessWidget {
  const _SlideThree();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // App icon-style logo with magnifier
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teal.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'P',
                    style: GoogleFonts.nunito(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: const Icon(Icons.search,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PetaFinds',
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text1,
                    letterSpacing: -0.6,
                  )),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text("Colombo's wholesale marketplace",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.text3,
              )),
          const SizedBox(height: 16),

          // Benefits card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: const [
                _BenefitRow(
                  icon: Icons.search,
                  title: 'Search any product',
                  subtitle: 'Find it across all of Pettah instantly',
                ),
                SizedBox(height: 10),
                Divider(color: AppColors.border, height: 1),
                SizedBox(height: 10),
                _BenefitRow(
                  icon: Icons.storefront_outlined,
                  title: 'See every seller',
                  subtitle: 'Compare prices before you visit',
                ),
                SizedBox(height: 10),
                Divider(color: AppColors.border, height: 1),
                SizedBox(height: 10),
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text1,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: AppColors.text3,
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
      color: AppColors.text2,
      height: 1.4,
    );
    final link = GoogleFonts.dmSans(
      fontSize: 12.5,
      color: AppColors.orange,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.orange,
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
          side: const BorderSide(color: AppColors.text4),
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
