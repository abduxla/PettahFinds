import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_colors.dart';

/// Soft "verify your email" banner. Shows only when:
///   - a Firebase user is signed in,
///   - that user's `emailVerified` is `false`,
///   - the user hasn't dismissed the banner this session.
///
/// Tapping "Resend" calls [AuthRepository.resendEmailVerification]. The
/// banner is intentionally non-blocking — review/report flows still work.
/// Hard-gating is a follow-up; this just nudges new accounts to verify.
class VerifyEmailBanner extends ConsumerStatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  ConsumerState<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends ConsumerState<VerifyEmailBanner> {
  bool _dismissed = false;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final firebaseUser = ref.watch(authStateProvider).valueOrNull;
    if (firebaseUser == null) return const SizedBox.shrink();
    // `emailVerified` only updates after `reload()`. Treating it as a
    // session-fresh value is fine — we re-check on next launch.
    if (firebaseUser.emailVerified) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verify your email to keep your account.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text1,
              ),
            ),
          ),
          TextButton(
            onPressed: _sending
                ? null
                : () async {
                    setState(() => _sending = true);
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .resendEmailVerification();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Verification email sent')),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? 'Failed')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _sending = false);
                    }
                  },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: _sending
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.orange),
                  )
                : Text(
                    'Resend',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          IconButton(
            onPressed: () => setState(() => _dismissed = true),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close, color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}
