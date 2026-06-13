import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-product engagement counters, stored at `product_stats/{productId}`.
/// Lets a seller see which individual listings are pulling views and chats,
/// not just the shop total. Written best-effort by [AnalyticsRepository].
class ProductStat {
  final String productId;
  final String businessId;
  final int views;
  final int chats;

  const ProductStat({
    required this.productId,
    required this.businessId,
    this.views = 0,
    this.chats = 0,
  });

  factory ProductStat.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    int read(String k) => (data[k] as num?)?.toInt() ?? 0;
    return ProductStat(
      productId: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      views: read('views'),
      chats: read('chats'),
    );
  }
}
