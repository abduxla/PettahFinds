import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/product_review_repository.dart';
import '../../repositories/favorite_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../services/account_deletion_service.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../services/recently_viewed_service.dart';
import '../../models/business.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/product.dart';
import '../../models/product_review.dart';
import '../../models/report.dart';

// --- Repositories ---
final authRepositoryProvider = Provider((ref) => AuthRepository());
final businessRepositoryProvider = Provider((ref) => BusinessRepository());
final productRepositoryProvider = Provider((ref) => ProductRepository());
final categoryRepositoryProvider = Provider((ref) => CategoryRepository());
final reviewRepositoryProvider = Provider((ref) => ReviewRepository());
final productReviewRepositoryProvider =
    Provider((ref) => ProductReviewRepository());
final favoriteRepositoryProvider = Provider((ref) => FavoriteRepository());
final reportRepositoryProvider = Provider((ref) => ReportRepository());
final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository());

// --- Services ---
final storageServiceProvider = Provider((ref) => StorageService());
final recentlyViewedServiceProvider =
    Provider((ref) => RecentlyViewedService());
final chatServiceProvider = Provider((ref) => ChatService());
final accountDeletionServiceProvider =
    Provider((ref) => AccountDeletionService());

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

/// Live total of unread chat messages for the signed-in user across every
/// thread they're a participant in. Sums both the customer-side and
/// seller-side unread counters because business owners are also customers
/// of other businesses — they care about both inboxes. Powered by the
/// same Firestore snapshot the chat list already subscribes to, so the
/// badge tick updates instantly without an extra query.
final totalUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(0);
  final service = ref.watch(chatServiceProvider);
  return service.streamAllForUser(uid).map((convs) {
    var total = 0;
    for (final c in convs) {
      if (c.customerId == uid) total = total + c.unreadCountCustomer;
      if (c.sellerId == uid) total = total + c.unreadCountSeller;
    }
    return total;
  });
});

/// Shared stream of all active products. Used by ADMIN surfaces +
/// downstream verified-filter providers — admins see the raw list
/// including products belonging to unverified businesses. Customer
/// surfaces should consume [customerVisibleProductsProvider] so they
/// only ever see products whose business is verified.
final allActiveProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).streamAll();
});

/// Customer-facing stream of products — filtered to those whose
/// business is verified. Powers the home grid, products list,
/// recommended sections, anywhere a customer browses.
///
/// Why client-side join: products don't denormalize `businessVerified`,
/// so we cross-reference against [allBusinessesProvider] (which is
/// already verified-only) and emit the intersection. Both upstreams
/// are already in memory for other screens, so this is a cheap
/// in-memory filter, not extra Firestore reads.
///
/// While either upstream is still loading, the loading state is passed
/// through so consumers show their existing shimmer/error UI unchanged.
final customerVisibleProductsProvider =
    Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(allActiveProductsProvider);
  final businesses = ref.watch(allBusinessesProvider);
  if (products.isLoading || businesses.isLoading) {
    return const AsyncValue.loading();
  }
  if (products.hasError) {
    return AsyncValue.error(
        products.error!, products.stackTrace ?? StackTrace.current);
  }
  if (businesses.hasError) {
    return AsyncValue.error(
        businesses.error!, businesses.stackTrace ?? StackTrace.current);
  }
  final verifiedIds =
      businesses.requireValue.map((b) => b.id).toSet();
  return AsyncValue.data(products.requireValue
      .where((p) => verifiedIds.contains(p.businessId))
      .toList());
});

/// Live newest-100 reviews for a single product. Mirrors
/// `reviewsByBusinessProvider` (business reviews) but pulls from the
/// `productReviews` collection — see [ProductReviewRepository].
final productReviewsProvider = StreamProvider.autoDispose
    .family<List<ProductReview>, String>((ref, productId) {
  if (productId.isEmpty) return Stream.value(const []);
  return ref
      .watch(productReviewRepositoryProvider)
      .streamByProduct(productId);
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

/// Single-business lookup, autoDispose so unused subscriptions don't
/// linger. Family keyed on business id. Used by every customer surface
/// that renders product cards (home, search, saved, products list) to
/// fetch the parent business for street-pin / counterparty display.
final businessByIdProvider =
    FutureProvider.autoDispose.family<Business?, String>((ref, id) async {
  if (id.isEmpty) return null;
  try {
    return await ref.watch(businessRepositoryProvider).getById(id);
  } catch (_) {
    return null;
  }
});

/// Streamed set of productIds favorited by a given user. Used by the
/// heart button on every product card to render true saved state and
/// drive the toggle.
final userFavoriteProductIdsProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, uid) {
  return ref
      .watch(favoriteRepositoryProvider)
      .streamByUser(uid)
      .map((list) => list
          .where((f) => f.targetType == 'product')
          .map((f) => f.targetId)
          .toSet());
});

/// Customer-facing list of businesses — verified only. Powers home,
/// the businesses list screen, the map. Unverified listings are hidden
/// from the public until an admin approves them.
///
/// Admin moderation surfaces (admin shell tabs) must use
/// [allBusinessesAdminProvider] or [pendingBusinessesProvider] to see
/// the full set including pending review.
final allBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamAll();
});

/// Admin-only stream of every business, verified or not. The Firestore
/// rule rejects non-admin readers when an unverified doc is in the
/// result set, so this provider will surface a permission-denied error
/// if accidentally watched from a non-admin context.
final allBusinessesAdminProvider = StreamProvider<List<Business>>((ref) {
  return ref
      .watch(businessRepositoryProvider)
      .streamAllIncludingPending();
});

/// Admin-only stream of businesses awaiting review (isVerified == false).
/// Drives the Pending tab in the admin Businesses screen and the
/// "pending review" count on the dashboard.
final pendingBusinessesProvider = StreamProvider<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).streamPending();
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

/// Products filtered by category. Raw stream — surfaces both verified
/// and unverified businesses' products. Customer screens should consume
/// [customerVisibleProductsByCategoryProvider] instead.
final productsByCategoryProvider = StreamProvider.autoDispose
    .family<List<Product>, String>((ref, category) {
  if (category.isEmpty) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).streamByCategory(category);
});

/// Customer-facing version of [productsByCategoryProvider] — same
/// verified-business join as [customerVisibleProductsProvider].
final customerVisibleProductsByCategoryProvider = Provider.autoDispose
    .family<AsyncValue<List<Product>>, String>((ref, category) {
  if (category.isEmpty) return const AsyncValue.data(<Product>[]);
  final products = ref.watch(productsByCategoryProvider(category));
  final businesses = ref.watch(allBusinessesProvider);
  if (products.isLoading || businesses.isLoading) {
    return const AsyncValue.loading();
  }
  if (products.hasError) {
    return AsyncValue.error(
        products.error!, products.stackTrace ?? StackTrace.current);
  }
  if (businesses.hasError) {
    return AsyncValue.error(
        businesses.error!, businesses.stackTrace ?? StackTrace.current);
  }
  final verifiedIds =
      businesses.requireValue.map((b) => b.id).toSet();
  return AsyncValue.data(products.requireValue
      .where((p) => verifiedIds.contains(p.businessId))
      .toList());
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
