import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      icon: Icons.storefront_rounded,
      title: 'Discover Local Businesses',
      description:
          'Find the best shops, restaurants, and services in your area.',
    ),
    _OnboardingPage(
      icon: Icons.shopping_bag_rounded,
      title: 'Browse Products & Deals',
      description:
          'Compare prices, check stock, and never miss a great deal.',
    ),
    _OnboardingPage(
      icon: Icons.star_rounded,
      title: 'Rate & Review',
      description:
          'Share your experiences and help others discover quality businesses.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon,
                              size: 56, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 40),
                        Text(page.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        Text(page.description,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
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
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/sign-up'),
                    child: const Text('Get Started'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPage(
      {required this.icon, required this.title, required this.description});
}
