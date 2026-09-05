import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;

  /// Optional id of the content this notification points at (e.g. a
  /// productId for a 'product' notification, a businessId for 'business').
  /// Set by the follow Cloud Functions so the inbox tile can deep-link;
  /// empty for older notifications that carry no target.
  final String targetId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.targetId = '',
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      targetId: data['targetId'] ?? '',
      read: data['read'] ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        if (targetId.isNotEmpty) 'targetId': targetId,
        'read': read,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
