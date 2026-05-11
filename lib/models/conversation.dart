import 'package:cloud_firestore/cloud_firestore.dart';

/// One thread per (product, customer) — both parties write into the same
/// doc identified by `${productId}_${customerId}` so the rule can authorize
/// by `participantIds` membership.
class Conversation {
  final String id;
  final String productId;
  final String productTitle;
  final String productImage;
  final String businessId;
  final String businessName;
  final String sellerId;
  final String customerId;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderId;
  final int unreadCountSeller;
  final int unreadCountCustomer;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.businessId,
    required this.businessName,
    required this.sellerId,
    required this.customerId,
    required this.participantIds,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderId = '',
    this.unreadCountSeller = 0,
    this.unreadCountCustomer = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static String idFor({required String productId, required String customerId}) =>
      '${productId}_$customerId';

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      productId: data['productId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      productImage: data['productImage'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      sellerId: data['sellerId'] ?? '',
      customerId: data['customerId'] ?? '',
      participantIds:
          (data['participantIds'] as List?)?.cast<String>() ?? const [],
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'] ?? '',
      unreadCountSeller: (data['unreadCountSeller'] as num?)?.toInt() ?? 0,
      unreadCountCustomer:
          (data['unreadCountCustomer'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'id': id,
        'productId': productId,
        'productTitle': productTitle,
        'productImage': productImage,
        'businessId': businessId,
        'businessName': businessName,
        'sellerId': sellerId,
        'customerId': customerId,
        'participantIds': participantIds,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt == null
            ? null
            : Timestamp.fromDate(lastMessageAt!),
        'lastSenderId': lastSenderId,
        'unreadCountSeller': unreadCountSeller,
        'unreadCountCustomer': unreadCountCustomer,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
