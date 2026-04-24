import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      heroEmoji: '🏪',
      heroSubEmojis: ['🧵', '💎', '🌶️'],
      title: "Discover Colombo's\nWholesale Hub",
      description:
          'Connect directly with business owners and find the best deals in Pettah, all in one place.',
    ),
    _OnboardingPage(
      heroEmoji: '🗺️',
      heroSubEmojis: ['📍', '🔍', '⭐'],
      title: 'Navigate Streets\n& Find Shops',
      description:
          'Explore Pettah street by street with our interactive map. Never miss a hidden gem again.',
    ),
    _OnboardingPage(
      heroEmoji: '🛍️',
      heroSubEmojis: ['💰', '📦', '🏷️'],
      title: 'Compare Prices\n& Save More',
      description:
          'Browse wholesale products, compare prices across shops, and get the best bulk deals.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.go('/sign-up');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Column(
                    children: [
                      // ---- Hero illustration area ----
                      Expanded(
                        flex: 5,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0A5858),
                                AppColors.teal,
                                Color(0xFF1A8A8A),
                              ],
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative circles
                              Positioned(
                                top: -30,
                                right: -20,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -50,
                                left: -30,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // Decorative sub-emojis
                              Positioned(
                                top: 30,
                                left: 30,
                                child: Text(page.heroSubEmojis[0],
                                    style: const TextStyle(fontSize: 28)),
                              ),
                              Positioned(
                                top: 40,
                                right: 35,
                                child: Text(page.heroSubEmojis[1],
                                    style: const TextStyle(fontSize: 24)),
                              ),
                              Positioned(
                                bottom: 35,
                                right: 50,
                                child: Text(page.heroSubEmojis[2],
                                    style: const TextStyle(fontSize: 26)),
                              ),
                              // Central big emoji
                              Text(
                                page.heroEmoji,
                                style: const TextStyle(fontSize: 80),
                              ),
                              // Brand banner
                              Positioned(
                                top: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.25),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'PETTAHFINDS',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- Text content area ----
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.text1,
                                  letterSpacing: -0.8,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.text3,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ---- Dots ----
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.teal
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ---- Next / Get Started button ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButton(
                onPressed: _nextPage,
                child: Text(
                  _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ---- Skip link ----
            TextButton(
              onPressed: () => context.go('/sign-in'),
              child: Text(
                'Skip',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String heroEmoji;
  final List<String> heroSubEmojis;
  final String title;
  final String description;
  const _OnboardingPage({
    required this.heroEmoji,
    required this.heroSubEmojis,
    required this.title,
    required this.description,
  });
}
