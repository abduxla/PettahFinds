import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_review.dart';

/// Mirrors [ReviewRepository] but scoped to individual products. Kept
/// as its own class (and its own collection `productReviews`) instead
/// of generalising the business-review repo so the incremental rating
/// aggregator can target the product doc unambiguously and so the
/// Firestore rules can require the referenced product to exist (which
/// also pins the businessId in the review for client-side filtering).
class ProductReviewRepository {
  final FirebaseFirestore _firestore;

  ProductReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('productReviews');

  Future<void> add(ProductReview review) async {
    final doc = _ref.doc();
    await doc.set({
      ...review.toMap(),
      'id': doc.id,
    });
    await _bumpProductRating(
      productId: review.productId,
      newRating: review.rating,
    );
  }

  /// Incrementally maintain ratingAvg + ratingCount on the product doc
  /// the same way `ReviewRepository._bumpBusinessRating` does for
  /// businesses. The matching Firestore rule allows any signed-in user
  /// to write *only* these two fields, only when the count increments
  /// by exactly 1 and the avg is in [1.0, 5.0].
  Future<void> _bumpProductRating({
    required String productId,
    required double newRating,
  }) async {
    final prodRef = _firestore.collection('products').doc(productId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(prodRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final oldCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final oldAvg = (data['ratingAvg'] as num?)?.toDouble() ?? 0.0;
      final newCount = oldCount + 1;
      final clamped = newRating.clamp(1.0, 5.0);
      final raw = (oldAvg * oldCount + clamped) / newCount;
      final newAvg = raw.clamp(1.0, 5.0);
      txn.update(prodRef, {
        'ratingAvg': double.parse(newAvg.toStringAsFixed(1)),
        'ratingCount': newCount,
      });
    });
  }

  /// Live stream cap. Older reviews still contribute to the product's
  /// aggregated rating; the list view loads them via [getOlderByProduct]
  /// on demand.
  static const _streamLimit = 100;

  Stream<List<ProductReview>> streamByProduct(String productId) {
    return _ref
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(ProductReview.fromFirestore).toList());
  }

  Future<List<ProductReview>> getOlderByProduct({
    required String productId,
    required DateTime before,
    int limit = 50,
  }) async {
    final snap = await _ref
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map(ProductReview.fromFirestore).toList();
  }
}
