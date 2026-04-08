import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String userId;
  final String? businessId;
  final String? productId;
  final String reason;
  final String status; // 'pending', 'reviewed', 'resolved'
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.userId,
    this.businessId,
    this.productId,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      userId: data['userId'] ?? '',
      businessId: data['businessId'],
      productId: data['productId'],
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'businessId': businessId,
        'productId': productId,
        'reason': reason,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}