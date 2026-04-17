import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/favorite_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../services/storage_service.dart';
import '../../services/recently_viewed_service.dart';
import '../../models/product.dart';

// --- Repositories ---
final authRepositoryProvider = Provider((ref) => AuthRepository());
final businessRepositoryProvider = Provider((ref) => BusinessRepository());
final productRepositoryProvider = Provider((ref) => ProductRepository());
final categoryRepositoryProvider = Provider((ref) => CategoryRepository());
final reviewRepositoryProvider = Provider((ref) => ReviewRepository());
final favoriteRepositoryProvider = Provider((ref) => FavoriteRepository());
final reportRepositoryProvider = Provider((ref) => ReportRepository());
final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository());

// --- Services ---
final storageServiceProvider = Provider((ref) => StorageService());
final recentlyViewedServiceProvider =
    Provider((ref) => RecentlyViewedService());

/// Shared stream of all active products. Used by home and products list
/// so we keep a single Firestore subscription instead of duplicating.
final allActiveProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).streamAll();
});

/// Resolves recently-viewed product IDs into full Product objects.
/// Silently skips deleted / inactive products so the UI never breaks.
final recentlyViewedProductsProvider =
    FutureProvider<List<Product>>((ref) async {
  final ids = await ref.watch(recentlyViewedServiceProvider).getIds();
  if (ids.isEmpty) return const [];
  final repo = ref.watch(productRepositoryProvider);
  final results = <Product>[];
  for (final id in ids) {
    try {
      final p = await repo.getById(id);
      if (p.isActive) results.add(p);
    } catch (_) {
      // Skip missing products.
    }
  }
  return results;
});

// --- Auth State ---
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// --- Current AppUser ---
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).streamAppUser(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// --- Business for current user ---
final currentUserBusinessProvider = FutureProvider<dynamic>((ref) async {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null || !appUser.isBusiness) return null;
  if (appUser.businessId != null && appUser.businessId!.isNotEmpty) {
    return ref.read(businessRepositoryProvider).getById(appUser.businessId!);
  }
  return ref.read(businessRepositoryProvider).getByOwnerUid(appUser.uid);
});
