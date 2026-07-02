import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/review.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.reviewsCollection);

  /// Upsert the caller's single review for a business. The doc id is pinned
  /// to `${userId}_${businessId}` so re-reviewing overwrites the previous
  /// rating instead of stacking duplicates (enforced by firestore.rules).
  ///
  /// Rating aggregation (ratingAvg / ratingCount) is owned entirely by the
  /// `onReviewWritten` Cloud Function — the client never writes those fields.
  Future<void> add(Review review) async {
    final id = '${review.userId}_${review.businessId}';
    await _ref.doc(id).set({
      ...review.toMap(),
      'id': id,
    });
  }

  /// Caps the per-business review stream. Older reviews still drive the
  /// average via [_updateBusinessRating], but the UI list shows the most
  /// recent 100 to keep client cost bounded.
  static const _streamLimit = 100;

  /// Streams the newest reviews for one business. Composite-index-free
  /// implementation — see the matching comment on
  /// [ProductReviewRepository.streamByProduct] for the full rationale.
  /// In short: drops the server-side orderBy so the query needs only
  /// the auto-created single-field index on `businessId`, then sorts
  /// in memory.
  Stream<List<Review>> streamByBusiness(String businessId) {
    return _ref
        .where('businessId', isEqualTo: businessId)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Review.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// One-shot fetch of older reviews for "Load more". Same
  /// composite-index-free strategy as [streamByBusiness].
  Future<List<Review>> getOlderByBusiness({
    required String businessId,
    required DateTime before,
    int limit = 50,
  }) async {
    final snap = await _ref
        .where('businessId', isEqualTo: businessId)
        .get();
    final all = snap.docs.map(Review.fromFirestore).toList();
    final older = all.where((r) => r.createdAt.isBefore(before)).toList();
    older.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return older.take(limit).toList();
  }
}
