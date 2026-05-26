import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Bottom sheet shown to a NEW OAuth user (Google / Apple) on the
/// sign-up screen to capture their role before /users/{uid} is
/// seeded. Returns `'user'` or `'business'`.
///
/// NOT DISMISSIBLE. By the time this sheet opens, Firebase Auth has
/// already created the user — if the caller could dismiss without
/// picking, we'd strand an authenticated session with no /users/{uid}
/// doc, which left earlier builds in a permanent loading loop with no
/// way to sign out. The sheet must end in a role choice OR an explicit
/// Cancel that triggers a clean signOut.
Future<String?> showSignupRolePickerSheet(
  BuildContext context, {
  /// Defaults to true and should almost always stay true.
  /// Exposed so callers can be explicit about their intent at the
  /// OAuth call-site (see sign_up_screen / sign_in_screen
  /// _continueWithOAuth) and so a regression that drops the root
  /// navigator can be caught by a passing test.
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    // CRITICAL: see header comment. Tapping the scrim must NOT dismiss
    // and the user must NOT be able to swipe the sheet away — both
    // paths historically stranded auth state.
    isDismissible: false,
    enableDrag: false,
    // CRITICAL: pin the sheet to the ROOT Navigator, not whichever
    // GoRoute happens to be on top when we open it. Without this, any
    // mid-OAuth route rebuild (e.g. router reacting to the appUser
    // stream emitting the new doc) tore down the sheet's host
    // Navigator and the await resolved with `null` — leaving an
    // authed Firebase user with no /users doc and tripping the
    // "Something went wrong" timeout downstream. Root-navigator
    // hosting survives every nested route swap.
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'I am joining as:',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 16),
            _RoleOption(
              icon: Icons.person_rounded,
              title: 'Customer',
              subtitle: 'Browse Pettah shops, save favorites, chat.',
              onTap: () => Navigator.of(sheetCtx).pop('user'),
            ),
            const SizedBox(height: 10),
            _RoleOption(
              icon: Icons.store_rounded,
              title: 'Business',
              subtitle: 'List your shop + products. Approved by admin.',
              onTap: () => Navigator.of(sheetCtx).pop('business'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Business accounts take 24-48 hours to review. While you wait, you can set up your profile and upload products. Once approved, your shop goes live for all customers!',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.text2,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Explicit Cancel — the only escape hatch now that the
            // sheet is non-dismissible. Returning null tells the
            // caller to sign the orphan Firebase Auth session out.
            TextButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.teal.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.text2,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.teal),
          ],
        ),
      ),
    );
  }
}
