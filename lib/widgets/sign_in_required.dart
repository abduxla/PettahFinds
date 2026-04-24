import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Unified sign-in prompt used when a guest taps an auth-gated action
/// (e.g. favouriting a product / business). Dismissable modal bottom
/// sheet — NEVER use a SnackBar for this, since repeated taps stack them
/// and leave a persistent black bar at the bottom of the screen.
///
/// Returns after the sheet is dismissed or the user navigates away.
Future<void> showSignInRequiredSheet(
  BuildContext context, {
  String title = 'Sign in required',
  String message =
      'Sign in to save favourites and keep track of the businesses you like.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (sheetCtx) => _SignInRequiredSheet(
      title: title,
      message: message,
    ),
  );
}

class _SignInRequiredSheet extends StatelessWidget {
  final String title;
  final String message;
  const _SignInRequiredSheet({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_outline,
                  color: AppColors.teal, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Not now',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/sign-in');
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state surface shown on screens that require authentication
/// (favorites, profile, notifications). Guests landing on these screens
/// see this and can jump to the sign-in flow.
class SignInRequired extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SignInRequired({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.teal),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.text1,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 220,
              height: 46,
              child: FilledButton(
                onPressed: () => context.go('/sign-in'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign in',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/sign-up'),
              child: Text(
                'Create an account',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
