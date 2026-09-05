import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/sign_in_required.dart';

/// The businesses the signed-in user follows.
///
/// Following a business subscribes the user to push + in-app notifications
/// for its new products and price drops. Rows open the shop; the trailing
/// button unfollows (the list is driven by [followedBusinessIdsProvider],
/// so it updates live). Distinct from Saved Items, which is a silent
/// bookmark list.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: appUser == null
          ? _SignedOut()
          : ref.watch(followedBusinessIdsProvider(appUser.uid)).when(
                data: (ids) {
                  if (ids.isEmpty) return _EmptyFollowing();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: ids.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => _FollowingTile(
                      businessId: ids[index],
                      uid: appUser.uid,
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _EmptyFollowing(),
              ),
    );
  }
}

/// One followed business. Loads its details lazily and offers an unfollow
/// action inline.
class _FollowingTile extends ConsumerWidget {
  const _FollowingTile({required this.businessId, required this.uid});

  final String businessId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessAsync = ref.watch(businessByIdProvider(businessId));

    return businessAsync.when(
      data: (business) {
        if (business == null) return const SizedBox.shrink();
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/home/business/${business.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: CachedImage(
                        imageUrl: business.logoUrl,
                        fit: BoxFit.cover,
                        placeholderIcon: Icons.storefront,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(business.businessName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('${business.category} · ${business.location}',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await ref.read(followRepositoryProvider).toggle(
                            userId: uid,
                            businessId: business.id,
                          );
                      if (!context.mounted) return;
                      context.showSuccessSnackBar('Unfollowed');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    child: const Text('Following'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _EmptyFollowing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text("You're not following anyone yet",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Open a shop and tap Follow to get notified when it posts new '
              'products or drops a price.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/home/businesses'),
              icon: const Icon(Icons.store_outlined, size: 18),
              label: const Text('Browse businesses'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Sign in to follow businesses',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Following lets you get notified about new products and deals '
              'from the shops you care about.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => showSignInRequiredSheet(context),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
