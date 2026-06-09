import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  /// The user who FILED the report (the reporter / blocker).
  final String userId;
  final String? businessId;
  final String? productId;
  /// For `targetType == 'user'` reports (e.g. a block), the uid of the
  /// user who was reported / blocked. Lets the admin moderation screen
  /// resolve who-blocked-whom and review the context.
  final String? reportedUserId;
  final String? targetType; // 'product' | 'business' | 'user'
  final String reason;
  final String? details;
  final String status; // 'pending', 'reviewed', 'resolved'
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.userId,
    this.businessId,
    this.productId,
    this.reportedUserId,
    this.targetType,
    required this.reason,
    this.details,
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
      reportedUserId: data['reportedUserId'],
      targetType: data['targetType'],
      reason: data['reason'] ?? '',
      details: data['details'],
      status: data['status'] ?? 'pending',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'businessId': businessId,
        'productId': productId,
        'reportedUserId': reportedUserId,
        'targetType': targetType,
        'reason': reason,
        'details': details,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
