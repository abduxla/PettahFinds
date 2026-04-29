import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      body: ListView(
        children: [
          _Section(title: 'Account', theme: theme),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            iconColor: theme.colorScheme.primary,
            title: 'Edit Profile',
            onTap: () {
              // TODO: navigate to edit profile
            },
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Change Password',
            onTap: () {
              // TODO: navigate to change password
            },
          ),
          _Section(title: 'Preferences', theme: theme),
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            secondary: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: Color(0xFFF59E0B), size: 20),
            ),
            title: const Text('Push Notifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
            value: true,
            onChanged: (val) {},
          ),
          _Section(title: 'Legal', theme: theme),
          _SettingsTile(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF22C55E),
            title: 'User Terms of Use',
            onTap: () => context.push('/legal/user-terms'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF22C55E),
            title: 'Privacy Policy',
            onTap: () => context.push('/legal/privacy'),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _Section({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Text(title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: 0.5,
          )),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          )),
      trailing: Icon(Icons.chevron_right_rounded,
          color: theme.colorScheme.outline, size: 22),
      onTap: onTap,
    );
  }
}
