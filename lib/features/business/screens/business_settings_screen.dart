import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class BusinessSettingsScreen extends ConsumerWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text('Settings',
            style: GoogleFonts.nunito(
              color: AppColors.text1,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ---- BUSINESS ----
          _SectionCard(
            label: 'BUSINESS',
            items: [
              _MenuItem(
                icon: Icons.edit_rounded,
                label: 'Edit Business Profile',
                onTap: () => context.go('/business-settings/edit-profile'),
              ),
              _MenuItem(
                icon: Icons.inventory_2_rounded,
                label: 'Manage Products',
                onTap: () => context.go('/business/products'),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ---- ACCOUNT ----
          _SectionCard(
            label: 'ACCOUNT',
            items: [
              _MenuItem(
                icon: Icons.workspace_premium_rounded,
                label: 'Membership & Billing',
                subtitle: 'Manage your subscription',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ---- LEGAL ----
          _SectionCard(
            label: 'LEGAL',
            items: [
              _MenuItem(
                icon: Icons.description_outlined,
                label: 'User Terms of Use',
                onTap: () => context.push('/legal/user-terms'),
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => context.push('/legal/privacy'),
              ),
              _MenuItem(
                icon: Icons.handshake_outlined,
                label: 'Business Listing Agreement',
                onTap: () =>
                    context.push('/legal/business-listing-agreement'),
              ),
              _MenuItem(
                icon: Icons.policy_outlined,
                label: 'Content and Prohibited Listings Policy',
                onTap: () => context.push('/legal/prohibited-listings'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ---- Sign Out ----
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content:
                      const Text('Are you sure you want to sign out?'),
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
              foregroundColor: AppColors.red,
              side: BorderSide(
                  color: AppColors.red.withAlpha(60)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Section Card — Labeled group of menu items (same pattern as Profile)
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
                    subtitle: item.subtitle != null
                        ? Text(item.subtitle!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.text3,
                            ))
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded,
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
  final String? subtitle;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
}
