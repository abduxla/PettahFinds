import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/sign_in_required.dart';

/// Back handler — always route to /home. Notifications lives under the
/// Profile shell branch, so `pop()` can bounce into Profile; explicit
/// /home keeps the UX predictable from every entry point (bell, deep link).
void _handleBack(BuildContext context) {
  context.go('/home');
}

/// Top-level provider so subscriptions are stable across rebuilds.
final _userNotificationsProvider = StreamProvider.autoDispose
    .family<List<AppNotification>, String>((ref, uid) {
  return ref.watch(notificationRepositoryProvider).streamByUser(uid);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final appUserAsync = ref.watch(appUserProvider);
    final appUser = appUserAsync.valueOrNull;

    // Auth still resolving → show a brief loader with a back escape hatch.
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgSection,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    // Guest → sign-in prompt (never spins).
    if (authState.valueOrNull == null) {
      return Scaffold(
        backgroundColor: AppColors.bgSection,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _handleBack(context),
          ),
          title: Text(
            'Notifications',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text1,
            ),
          ),
        ),
        body: const SignInRequired(
          icon: Icons.notifications_none_rounded,
          title: 'Sign in for notifications',
          subtitle:
              'Get alerts about deals, replies and updates from businesses you follow.',
        ),
      );
    }

    // Firebase user resolved but AppUser doc still loading → short-lived loader.
    if (appUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgSection,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final notificationsAsync =
        ref.watch(_userNotificationsProvider(appUser.uid));

    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationRepositoryProvider)
                .markAllAsRead(appUser.uid),
            child: Text(
              'Mark all read',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => notifications.isEmpty
            ? const _EmptyNotifications()
            : ListView.separated(
                itemCount: notifications.length,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _NotificationTile(
                  notification: notifications[i],
                  onTap: () {
                    if (!notifications[i].read) {
                      ref
                          .read(notificationRepositoryProvider)
                          .markAsRead(notifications[i].id);
                    }
                  },
                ),
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.teal)),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_userNotificationsProvider(appUser.uid)),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: n.read ? AppColors.bgSection : AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_rounded,
                color: n.read ? AppColors.text4 : AppColors.teal,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight:
                          n.read ? FontWeight.w500 : FontWeight.w700,
                      color: AppColors.text1,
                    ),
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.text2,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().add_jm().format(n.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      color: AppColors.text4,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 6),
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  color: AppColors.teal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll let you know when something important happens.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
