import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/favorite.dart';
import '../../../widgets/shimmer_loading.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    if (appUser == null) {
      return const Scaffold(body: DetailSkeleton());
    }

    final favoritesAsync = ref.watch(
      StreamProvider<List<Favorite>>(
          (ref) => ref.read(favoriteRepositoryProvider).streamByUser(appUser.uid)),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 60,
            title: Text('Profile',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  // Avatar + info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: theme.colorScheme.primary.withAlpha(50),
                                width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: theme.colorScheme.primaryContainer,
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
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(appUser.displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(appUser.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 18),

                        // Stats row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withAlpha(120),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite_rounded,
                                  size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              favoritesAsync.when(
                                data: (favs) => Text(
                                  '${favs.length} Favorites',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                loading: () => Text('... Favorites',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary)),
                                error: (_, _) => Text('0 Favorites',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Menu tiles
                  _buildMenuSection(context, theme, [
                    _MenuTile(
                      icon: Icons.favorite_outline_rounded,
                      label: 'My Favorites',
                      color: const Color(0xFFEF4444),
                      onTap: () => context.go('/favorites'),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.go('/profile/notifications'),
                    ),
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      color: const Color(0xFF6366F1),
                      onTap: () => context.go('/profile/settings'),
                    ),
                  ]),

                  const SizedBox(height: 14),

                  _buildMenuSection(context, theme, [
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About PetaFinds',
                      color: const Color(0xFF22C55E),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'PetaFinds',
                          applicationVersion: '1.0.0',
                          children: [
                            const Text('Discover local businesses & deals.'),
                          ],
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Sign out button
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
                        if (context.mounted) context.go('/sign-in');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                            color: theme.colorScheme.error.withAlpha(60)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context, ThemeData theme, List<_MenuTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
        children: List.generate(tiles.length, (i) {
          final tile = tiles[i];
          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tile.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tile.icon, color: tile.color, size: 20),
                ),
                title: Text(tile.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline, size: 22),
                onTap: tile.onTap,
              ),
              if (i < tiles.length - 1)
                Divider(
                  height: 1,
                  indent: 70,
                  color: theme.dividerTheme.color,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _MenuTile {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
