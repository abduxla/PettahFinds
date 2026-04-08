import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../models/app_notification.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    if (appUser == null) return const Scaffold(body: LoadingWidget());

    final notificationsAsync = ref.watch(
      StreamProvider<List<AppNotification>>((ref) =>
          ref.read(notificationRepositoryProvider).streamByUser(appUser.uid)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationRepositoryProvider)
                .markAllAsRead(appUser.uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => notifications.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.notifications_off_outlined,
                title: 'No notifications')
            : ListView.builder(
                itemCount: notifications.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.read
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.notifications,
                        color: n.read
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                            fontWeight:
                                n.read ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body),
                        Text(
                          DateFormat.yMMMd().add_jm().format(n.createdAt),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!n.read) {
                        ref
                            .read(notificationRepositoryProvider)
                            .markAsRead(n.id);
                      }
                    },
                  );
                },
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}
