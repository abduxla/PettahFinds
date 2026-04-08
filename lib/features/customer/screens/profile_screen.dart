import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/favorite.dart';
import '../../../widgets/loading_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    if (appUser == null) return const Scaffold(body: LoadingWidget());

    final favoritesAsync = ref.watch(
      StreamProvider<List<Favorite>>(
          (ref) => ref.read(favoriteRepositoryProvider).streamByUser(appUser.uid)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: appUser.photoUrl != null &&
                          appUser.photoUrl!.isNotEmpty
                      ? NetworkImage(appUser.photoUrl!)
                      : null,
                  child:
                      (appUser.photoUrl == null || appUser.photoUrl!.isEmpty)
                          ? Text(
                              appUser.displayName.isNotEmpty
                                  ? appUser.displayName[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.headlineMedium)
                          : null,
                ),
                const SizedBox(height: 12),
                Text(appUser.displayName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(appUser.email,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatBadge(
                icon: Icons.favorite,
                label: 'Favorites',
                value: favoritesAsync.when(
                  data: (favs) => favs.length.toString(),
                  loading: () => '...',
                  error: (_, _) => '0',
                ),
                color: theme.colorScheme.error,
              ),
            ],
          ),

          const SizedBox(height: 24),
          _ProfileTile(
            icon: Icons.favorite_outline,
            title: 'My Favorites',
            onTap: () => context.go('/favorites'),
          ),
          _ProfileTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => context.go('/profile/notifications'),
          ),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => context.go('/profile/settings'),
          ),
          _ProfileTile(
            icon: Icons.info_outline,
            title: 'About PetaFinds',
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/sign-in');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
