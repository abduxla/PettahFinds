import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Shown after business signup while the account is awaiting admin approval.
/// Not inside the business shell — it's a standalone scaffold so the
/// business nav bar doesn't appear for unverified owners.
/// The router redirects here automatically whenever isVerified == false,
/// and auto-exits to /business once the admin approves.
class BusinessPendingScreen extends StatelessWidget {
  const BusinessPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar — matches business dashboard header style
            Container(
              color: AppColors.tealDark,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Text(
                    'PetaFinds',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 2),
                    child: CircleAvatar(
                      radius: 3.5,
                      backgroundColor: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hourglass icon badge
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: AppColors.tealLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 44,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Under Review',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your business account is being verified',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.text3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Review timeline badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.orange.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppColors.orange, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Expected review time: 24–48 hours',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main message card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Thank you for registering your business with PetaFinds!\n\n'
                        'Your business account has been submitted successfully and '
                        'is currently under review by our team.\n\n'
                        'Our team will verify your business information and approve '
                        'your account within 24–48 hours.\n\n'
                        'Once approved, your business will become visible to thousands '
                        'of customers searching for products and shops in Pettah.\n\n'
                        'You will receive an email notification once your account '
                        'has been approved.\n\n'
                        'Thank you for joining PetaFinds — bringing Pettah online.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.65,
                          color: AppColors.text2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Primary CTA
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.explore_rounded, size: 20),
                      label: const Text('Browse the App'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You can explore PetaFinds as a customer while you wait.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.text4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
