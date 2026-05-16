import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-product review. Sibling of [Review] (business reviews) — kept in
/// a separate `productReviews` collection so the incremental rating
/// aggregator can update the parent product without confusing it with
/// a business rating, and so the Firestore rules can be scoped tightly
/// to the product-existence check instead of having to disambiguate
/// whether `businessId` or `productId` is the parent.
class ProductReview {
  final String id;
  final String productId;
  final String businessId;
  final String userId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.businessId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductReview(
      id: doc.id,
      productId: data['productId'] ?? '',
      businessId: data['businessId'] ?? '',
      userId: data['userId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'businessId': businessId,
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
