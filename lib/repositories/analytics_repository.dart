import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/business_stats.dart';
import '../models/product_stat.dart';

/// Records customer engagement against a business (and its individual
/// products) and streams the totals back for the seller analytics screen.
///
/// All `record*` methods are **best-effort**: they swallow errors so a
/// blocked or offline write never disrupts the customer's browsing. Writes
/// use `set(merge:true)` + `FieldValue.increment` so the stat docs are
/// created on first event and counters accumulate atomically.
///
/// Callers should skip recording when the viewer is the business owner (so
/// a seller opening their own shop doesn't inflate their numbers).
class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _stats =>
      _firestore.collection(AppConstants.businessStatsCollection);

  CollectionReference get _productStats =>
      _firestore.collection(AppConstants.productStatsCollection);

  Future<void> _bumpBusiness(String businessId, String field,
      [int delta = 1]) async {
    if (businessId.isEmpty) return;
    try {
      await _stats.doc(businessId).set({
        field: FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — analytics must never break browsing.
    }
  }

  Future<void> _bumpProduct(String productId, String businessId, String field,
      [int delta = 1]) async {
    if (productId.isEmpty || businessId.isEmpty) return;
    try {
      await _productStats.doc(productId).set({
        'businessId': businessId,
        field: FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> recordProfileView(String businessId) =>
      _bumpBusiness(businessId, 'profileViews');

  /// A product view bumps both the business total and the per-product count
  /// so the seller can see which listings are actually being browsed.
  Future<void> recordProductView(String businessId, String productId) async {
    await Future.wait([
      _bumpBusiness(businessId, 'productViews'),
      _bumpProduct(productId, businessId, 'views'),
    ]);
  }

  Future<void> recordChatStarted(String businessId, String productId) async {
    await Future.wait([
      _bumpBusiness(businessId, 'chatsStarted'),
      _bumpProduct(productId, businessId, 'chats'),
    ]);
  }

  /// A customer saving a product bumps both the business total and the
  /// per-product count; un-saving decrements, so the figure reflects the
  /// current number of savers rather than total taps.
  Future<void> recordProductSave(String businessId, String productId) async {
    await Future.wait([
      _bumpBusiness(businessId, 'saves'),
      _bumpProduct(productId, businessId, 'saves'),
    ]);
  }

  Future<void> recordProductUnsave(String businessId, String productId) async {
    await Future.wait([
      _bumpBusiness(businessId, 'saves', -1),
      _bumpProduct(productId, businessId, 'saves', -1),
    ]);
  }

  /// Live engagement totals for a business. Emits [BusinessStats.empty]
  /// until the first event lands (the doc won't exist yet).
  Stream<BusinessStats> streamStats(String businessId) {
    return _resilient(() => _stats.doc(businessId).snapshots().map(
          (doc) => doc.exists
              ? BusinessStats.fromFirestore(doc)
              : BusinessStats.empty,
        ));
  }

  /// Per-product engagement for a business, most-viewed first. Equality
  /// query only (no composite index needed); sorted client-side.
  Stream<List<ProductStat>> streamProductStats(String businessId) {
    return _resilient(() => _productStats
        .where('businessId', isEqualTo: businessId)
        .limit(200)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ProductStat.fromFirestore).toList();
      list.sort((a, b) => b.views.compareTo(a.views));
      return list;
    }));
  }

  /// Wraps a Firestore snapshot stream so a transient `permission-denied`
  /// (auth token not yet propagated to the listen channel on cold start or
  /// just after sign-in) re-subscribes a few times before surfacing. A
  /// genuine permission error still bubbles up after the retries.
  Stream<T> _resilient<T>(Stream<T> Function() build) async* {
    var attempt = 0;
    while (true) {
      try {
        yield* build();
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && attempt < 4) {
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }
}
