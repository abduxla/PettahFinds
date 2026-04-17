import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../models/favorite.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/empty_state_widget.dart';

final _userFavoritesProvider =
    StreamProvider.autoDispose.family<List<Favorite>, String>((ref, uid) {
  return ref.watch(favoriteRepositoryProvider).streamByUser(uid);
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    if (appUser == null) {
      return const Scaffold(body: LoadingWidget());
    }

    final favoritesAsync = ref.watch(_userFavoritesProvider(appUser.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesAsync.when(
        data: (favorites) => favorites.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.favorite_outline,
                title: 'No favorites yet',
                subtitle: 'Start exploring and save your favorites!')
            : ListView.builder(
                itemCount: favorites.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final fav = favorites[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          fav.targetType == 'business'
                              ? Icons.store
                              : Icons.shopping_bag,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        fav.targetType == 'business'
                            ? 'Business'
                            : 'Product',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                      subtitle: Text('ID: ${fav.targetId}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          ref.read(favoriteRepositoryProvider).toggle(
                                userId: appUser.uid,
                                targetType: fav.targetType,
                                targetId: fav.targetId,
                              );
                        },
                      ),
                      onTap: () {
                        if (fav.targetType == 'business') {
                          context.go('/home/business/${fav.targetId}');
                        } else {
                          context.go('/home/product/${fav.targetId}');
                        }
                      },
                    ),
                  );
                },
              ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_userFavoritesProvider(appUser.uid)),
        ),
      ),
    );
  }
}
