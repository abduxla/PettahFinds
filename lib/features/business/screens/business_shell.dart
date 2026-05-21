import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/unread_badge.dart';

class BusinessShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const BusinessShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgSection,
      body: navigationShell,
      bottomNavigationBar: _BusinessBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i,
            initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

class _BusinessBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BusinessBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live unread total across every conversation this merchant is in.
    // Drives the badge on the Messages tab; 0 hides the badge entirely.
    final unread =
        ref.watch(totalUnreadCountProvider).valueOrNull ?? 0;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.store_outlined,
              activeIcon: Icons.store_rounded,
              label: 'Profile',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
              label: 'Messages',
              selected: currentIndex == 2,
              badgeCount: unread,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  /// Optional unread-count badge overlay. 0 (default) hides the badge.
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.text4;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? AppColors.tealLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: UnreadBadge(
                count: badgeCount,
                child: Icon(
                  selected ? activeIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
