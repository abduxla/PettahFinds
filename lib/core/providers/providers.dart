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
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../services/recently_viewed_service.dart';
import '../../models/business.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/product.dart';
import '../../models/report.dart';

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
final chatServiceProvider = Provider((ref) => ChatService());

// --- Chat streams ---
final conversationStreamProvider = StreamProvider.autoDispose
    .family<Conversation?, String>((ref, id) {
  if (id.isEmpty) return Stream.value(null);
  return ref.watch(chatServiceProvider).streamConversation(id);
});

final conversationMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) {
  if (id.isEmpty) return Stream.value(const []);
  return ref.watch(chatServiceProvider).streamMessages(id);
});

final customerConversationsProvider = StreamProvider.autoDispose
    .family<List<Conversation>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const []);
  return ref.watch(chatServiceProvider).streamCustomerConversations(uid);
});

final sellerConversationsProvider = StreamProvider.autoDispose
    .family<List<Conversation>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const []);
  return ref.watch(chatServiceProvider).streamSellerConversations(uid);
});

/// Shared stream of all active products. Used by home and products list
/// so we keep a single Firestore subscription instead of duplicating.
final allActiveProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).streamAll();
});

/// All products (active + inactive) for a specific business. Used by the
/// business Manage Products screen. Top-level autoDispose.family so the
/// subscription is stable across rebuilds and invalidation actually works.
final businessProductsProvider =
    StreamProvider.autoDispose.family<List<Product>, String>((ref, businessId) {
  if (businessId.isEmpty) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).streamAllByBusiness(businessId);
});

/// Active-only products for a specific business. Used by the business
/// dashboard "Your Products" preview.
final businessActiveProductsProvider =
    StreamProvider.autoDispose.family<List<Product>, String>((ref, businessId) {
  if (businessId.isEmpty) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).streamByBusiness(businessId);
});

/// Top-level streams for the admin dashboard + listing screens. Lifted
/// out of `build()` so rebuilds don't construct fresh `StreamProvider`s
/// every frame (which leaks the previous Firestore subscription).
final allBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamAll();
});
final allReportsProvider = StreamProvider<List<Report>>((ref) {
  return ref.watch(reportRepositoryProvider).streamAll();
});

/// Businesses filtered by category. Family keyed on category name so each
/// distinct filter shares one Firestore subscription instead of creating
/// a fresh provider per `build()`.
final businessesByCategoryProvider = StreamProvider.autoDispose
    .family<List<Business>, String>((ref, category) {
  if (category.isEmpty) return Stream.value(const []);
  return ref.watch(businessRepositoryProvider).streamByCategory(category);
});

/// Resolves recently-viewed product IDs into full Product objects.
/// Silently skips deleted / inactive products so the UI never breaks.
/// Fans out reads in parallel and preserves the input order.
final recentlyViewedProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final ids = await ref.watch(recentlyViewedServiceProvider).getIds();
  if (ids.isEmpty) return const [];
  final repo = ref.watch(productRepositoryProvider);
  final fetched = await Future.wait(ids.map((id) async {
    try {
      final p = await repo.getById(id);
      return p.isActive ? p : null;
    } catch (_) {
      return null;
    }
  }));
  return fetched.whereType<Product>().toList();
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
//
// Typed `Business?`. Callers can use `valueOrNull` directly without an
// `as Business` cast. Invalidated explicitly after business create / edit
// so the dashboard reflects changes.
final currentUserBusinessProvider = FutureProvider<Business?>((ref) async {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null || !appUser.isBusiness) return null;
  if (appUser.businessId != null && appUser.businessId!.isNotEmpty) {
    return ref.read(businessRepositoryProvider).getById(appUser.businessId!);
  }
  return ref.read(businessRepositoryProvider).getByOwnerUid(appUser.uid);
});
