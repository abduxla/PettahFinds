import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/sign_in_required.dart';

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
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: () => context.go('/home'),
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
                        onTap: () => context.go('/profile/settings'),
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        onTap: () => context.go('/profile/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---- MARKETPLACE ACTIVITY ----
                  _SectionCard(
                    label: 'MARKETPLACE ACTIVITY',
                    items: [
                      _MenuItem(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'My Saved Items',
                        onTap: () => context.go('/favorites'),
                      ),
                      _MenuItem(
                        icon: Icons.store_outlined,
                        label: 'Business Directory',
                        onTap: () => context.go('/home/businesses'),
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
                        onTap: () {},
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
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'PetaFinds',
                            applicationVersion: '1.0.0',
                            children: [
                              const Text(
                                  'Discover local businesses & deals in Pettah.'),
                            ],
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.mail_outline_rounded,
                        label: 'Contact Us',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'PetaFinds',
                            applicationVersion: '1.0.0',
                            children: [
                              const Text(
                                  'Email: support@pettahfinds.com'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ---- Sign Out ----
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign Out')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/home');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(
                            color: AppColors.red.withAlpha(60)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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
class _ProfileHeader extends StatelessWidget {
  final dynamic appUser;
  const _ProfileHeader({required this.appUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar with edit badge
        Stack(
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
                backgroundImage: appUser.photoUrl != null &&
                        appUser.photoUrl!.isNotEmpty
                    ? NetworkImage(appUser.photoUrl!)
                    : null,
                child: (appUser.photoUrl == null ||
                        appUser.photoUrl!.isEmpty)
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
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgSection, width: 2.5),
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
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.text4, size: 22),
                    onTap: item.onTap,
                  ),
                  if (i < items.length - 1)
                    const Divider(
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
