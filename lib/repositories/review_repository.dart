import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/review.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.reviewsCollection);

  Future<void> add(Review review) async {
    final doc = _ref.doc();
    await doc.set({
      ...review.toMap(),
      'id': doc.id,
    });
    // Incremental aggregation — avoids scanning every review for the
    // business on every submit (which is O(n) per write). The Firestore
    // rule allows `ratingCount <= old + 1` and `ratingAvg in [1.0, 5.0]`,
    // which exactly matches this incremental update.
    await _bumpBusinessRating(
      businessId: review.businessId,
      newRating: review.rating,
    );
  }

  Future<void> _bumpBusinessRating({
    required String businessId,
    required double newRating,
  }) async {
    final bizRef = _firestore
        .collection(AppConstants.businessesCollection)
        .doc(businessId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(bizRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final oldCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final oldAvg = (data['ratingAvg'] as num?)?.toDouble() ?? 0.0;
      final newCount = oldCount + 1;
      final clamped = newRating.clamp(1.0, 5.0);
      final raw = (oldAvg * oldCount + clamped) / newCount;
      // Keep within rule bounds even if old data was malformed.
      final newAvg = raw.clamp(1.0, 5.0);
      txn.update(bizRef, {
        'ratingAvg': double.parse(newAvg.toStringAsFixed(1)),
        'ratingCount': newCount,
      });
    });
  }

  /// Caps the per-business review stream. Older reviews still drive the
  /// average via [_updateBusinessRating], but the UI list shows the most
  /// recent 100 to keep client cost bounded.
  static const _streamLimit = 100;

  Stream<List<Review>> streamByBusiness(String businessId) {
    return _ref
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Review.fromFirestore).toList());
  }

  /// One-shot fetch of older reviews for "Load more". Caller passes the
  /// `createdAt` of the oldest review currently rendered; we return the
  /// next [limit] reviews older than that.
  Future<List<Review>> getOlderByBusiness({
    required String businessId,
    required DateTime before,
    int limit = 50,
  }) async {
    final snap = await _ref
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map(Review.fromFirestore).toList();
  }
}
