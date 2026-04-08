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
    // Update business rating
    await _updateBusinessRating(review.businessId);
  }

  Future<void> _updateBusinessRating(String businessId) async {
    final snap =
        await _ref.where('businessId', isEqualTo: businessId).get();
    if (snap.docs.isEmpty) return;

    final reviews = snap.docs.map(Review.fromFirestore).toList();
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    await _firestore
        .collection(AppConstants.businessesCollection)
        .doc(businessId)
        .update({
      'ratingAvg': double.parse(avg.toStringAsFixed(1)),
      'ratingCount': reviews.length,
    });
  }

  Stream<List<Review>> streamByBusiness(String businessId) {
    return _ref
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Review.fromFirestore).toList());
  }
}
