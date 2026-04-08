import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String businessId;
  final String productId;
  final String productTitle;
  final String dateKey; // e.g. '2026-04-07'
  final double price;
  final String stockStatus; // 'in_stock', 'low', 'out'
  final DateTime updatedAt;
  final String updatedBy;

  const Offer({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productTitle,
    required this.dateKey,
    required this.price,
    required this.stockStatus,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory Offer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Offer(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      productId: data['productId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      dateKey: data['dateKey'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      stockStatus: data['stockStatus'] ?? 'in_stock',
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'businessId': businessId,
        'productId': productId,
        'productTitle': productTitle,
        'dateKey': dateKey,
        'price': price,
        'stockStatus': stockStatus,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': updatedBy,
      };
}
