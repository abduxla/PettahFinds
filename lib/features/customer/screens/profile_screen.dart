import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../widgets/delete_account_dialog.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/sign_in_required.dart';
import '../../../widgets/sign_out_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    // Guest → show sign-in prompt instead of a perpetual skeleton.
    if (authState.valueOrNull == null && !authState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
        ),
        body: const SignInRequired(
          icon: Icons.person_outline,
          title: 'Sign in to PetaFinds',
          subtitle:
              'Create an account or sign in to save favourites, manage your profile and receive notifications.',
        ),
      );
    }

    if (appUser == null) {
      return const Scaffold(body: DetailSkeleton());
    }

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 56,
            centerTitle: true,
            backgroundColor: AppColors.bgSection,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PetaFinds',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.teal,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              // Pop to whatever pushed us. Fall back to Home only when
              // /profile was reached via tab-switch or deep link (no
              // stack to pop).
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                children: [
                  // ---- Avatar + Name + Location ----
                  _ProfileHeader(appUser: appUser),

                  const SizedBox(height: 28),

                  // ---- ACCOUNT SETTINGS ----
                  _SectionCard(
                    label: 'ACCOUNT SETTINGS',
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit Profile',
                        onTap: () => context.go('/profile/edit'),
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        onTap: () => context.go('/profile/password'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---- MARKETPLACE ACTIVITY ----
                  _SectionCard(
                    label: 'MARKETPLACE ACTIVITY',
                    items: [
                      _MenuItem(
                        icon: Icons.forum_outlined,
                        label: 'Messages',
                        // push() so /profile stays on the stack and the
                        // arrow / swipe-back on the Messages screen lands
                        // back here.
                        onTap: () => context.push('/chat'),
                        // Live unread count next to the row. Pulls from
                        // the same Firestore snapshot the chat list does,
                        // so this stays in sync with the home-header badge.
                        trailing: _UnreadPill(
                          count: ref
                                  .watch(totalUnreadCountProvider)
                                  .valueOrNull ??
                              0,
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'My Saved Items',
                        // Tab switch — keep go() so the bottom nav
                        // updates to the Saved tab.
                        onTap: () => context.go('/favorites'),
                      ),
                      _MenuItem(
                        icon: Icons.store_outlined,
                        label: 'Business Directory',
                        // Cross-branch drill-down. push() keeps /profile
                        // underneath so swipe-back returns here.
                        onTap: () => context.push('/home/businesses'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---- APP PREFERENCES ----
                  _SectionCard(
                    label: 'APP PREFERENCES',
                    items: [
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => context.go('/profile/notifications'),
                      ),
                      _MenuItem(
                        icon: Icons.language_rounded,
                        label: 'Language',
                        trailing: Text(
                          'English',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.text3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---- APPEARANCE ----
                  // Dark-mode toggle intentionally hidden from the UI for now.
                  // The theming feature stays fully wired — re-add
                  // `const DarkModeSection(),` (widgets/dark_mode_tile.dart)
                  // here to bring the option back.

                  // ---- PRIVACY & SAFETY ----
                  _SectionCard(
                    label: 'PRIVACY & SAFETY',
                    items: [
                      _MenuItem(
                        icon: Icons.block_rounded,
                        label: 'Blocked Users',
                        onTap: () => context.go('/profile/blocked'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---- SUPPORT ----
                  _SectionCard(
                    label: 'SUPPORT',
                    items: [
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help Center',
                        onTap: () => context.go('/profile/support'),
                      ),
                      _MenuItem(
                        icon: Icons.mail_outline_rounded,
                        label: 'Contact Us',
                        onTap: () => context.go('/profile/contact'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ---- Sign Out (primary action) ----
                  // Promoted to the prominent filled-teal button per the
                  // visual hierarchy spec: signing out is the common,
                  // non-destructive action. Delete moves below as a
                  // quiet text link to discourage accidental taps.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final confirm = await showSignOutDialog(context);
                        if (confirm != true) return;
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/home');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ---- Delete account (subdued text link) ----
                  // Same destructive flow (showDeleteAccountFlow → type
                  // DELETE → re-auth → cascade wipe). Only the visual
                  // weight changes — no fill, no border, small grey
                  // label so it doesn't compete with Sign Out.
                  TextButton(
                    onPressed: () => showDeleteAccountFlow(
                      context,
                      ref,
                      isBusinessOwner: false,
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      foregroundColor: const Color(0xFF9E9E9E),
                    ),
                    child: Text(
                      'Delete account',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                  ),

                  // Bottom pad clears the floating bottom nav (~90 px)
                  // plus safe-area so the Sign Out button is fully visible.
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Profile Header — Avatar with edit badge + name + location
// =========================================================================
class _ProfileHeader extends ConsumerStatefulWidget {
  final AppUser appUser;
  const _ProfileHeader({required this.appUser});

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _uploading = false;

  AppUser get appUser => widget.appUser;

  /// Tapping the avatar / camera badge opens a chooser, picks a photo,
  /// uploads it to Storage, and writes the URL back onto the user doc.
  ///
  /// This was the App Review 2.1(a) rejection: the camera badge was a
  /// decorative icon with NO tap handler, so on iPad it looked like a
  /// button but did nothing ("camera button is unresponsive"). It is
  /// now a working profile-photo picker.
  Future<void> _changePhoto() async {
    if (_uploading) return;

    // Source chooser. showModalBottomSheet presents correctly on both
    // iPhone and iPad (the reviewer hit this on an iPad Air), and the
    // image_picker plugin internally anchors the native gallery/camera
    // UI, so no manual popover sourceRect is needed.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_camera_rounded,
                  color: AppColors.teal),
              title: Text('Take Photo',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded,
                  color: AppColors.teal),
              title: Text('Choose from Library',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (source == null) return; // sheet dismissed

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return; // user cancelled the camera/library
      if (!mounted) return;

      setState(() => _uploading = true);

      final bytes = await picked.readAsBytes();
      final storage = ref.read(storageServiceProvider);
      final repo = ref.read(authRepositoryProvider);

      // Overwrite a single deterministic path so we don't accumulate
      // orphaned avatars in Storage on every change. Path is under
      // users/{uid}/ to match the existing Storage rule that allows
      // a signed-in user to write their own profile photos.
      final url = await storage.uploadBytes(
        path: 'users/${appUser.uid}/avatar.jpg',
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      await repo.updateUser(appUser.copyWith(photoUrl: url));
      // Refresh so the new avatar shows immediately.
      ref.invalidate(appUserProvider);

      if (mounted) {
        context.showSuccessSnackBar('Profile photo updated');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        appUser.photoUrl != null && appUser.photoUrl!.isNotEmpty;
    return Column(
      children: [
        // Tappable avatar with camera badge.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _uploading ? null : _changePhoto,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.teal.withAlpha(40), width: 3),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.tealLight,
                  backgroundImage:
                      hasPhoto ? NetworkImage(appUser.photoUrl!) : null,
                  child: !hasPhoto
                      ? Text(
                          appUser.displayName.isNotEmpty
                              ? appUser.displayName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.nunito(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ))
                      : null,
                ),
              ),
              // Spinner overlay while uploading.
              if (_uploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.bgSection, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Name
        Text(
          appUser.displayName,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text1,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 4),

        // Location pill
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded,
                size: 14, color: AppColors.teal),
            const SizedBox(width: 3),
            Text(
              'Colombo, LK',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.text3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =========================================================================
// Section Card — Labeled group of menu items
// =========================================================================
class _SectionCard extends StatelessWidget {
  final String label;
  final List<_MenuItem> items;
  const _SectionCard({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon,
                          color: AppColors.teal, size: 20),
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                      ),
                    ),
                    trailing: item.trailing ??
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.text4, size: 22),
                    onTap: item.onTap,
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      color: AppColors.border,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
}

/// Small orange pill shown in the Messages row trailing slot. Hides when
/// the count is zero so the row reads cleanly when there's nothing new.
class _UnreadPill extends StatelessWidget {
  final int count;
  const _UnreadPill({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
