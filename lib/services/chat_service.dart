import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/business.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/product.dart';

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messagesRef(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  /// Open (or create) a thread for a (product, customer). Idempotent —
  /// deterministic id means double-tap on "Chat Seller" never duplicates.
  /// The seller is never allowed to create the doc (rule pins customerId
  /// to the caller), so this is invoked from the customer side only.
  Future<Conversation> openConversation({
    required Product product,
    required Business business,
    required String customerId,
  }) async {
    final id = Conversation.idFor(
      productId: product.id,
      customerId: customerId,
    );
    final docRef = _conversations.doc(id);
    final existing = await docRef.get();
    if (existing.exists) {
      return Conversation.fromFirestore(existing);
    }
    final now = DateTime.now();
    final conv = Conversation(
      id: id,
      productId: product.id,
      productTitle: product.title,
      productImage: product.image1Url,
      businessId: business.id,
      businessName: business.businessName,
      sellerId: business.ownerUid,
      customerId: customerId,
      participantIds: [business.ownerUid, customerId],
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(conv.toCreateMap());
    return conv;
  }

  Stream<Conversation?> streamConversation(String id) {
    return _conversations.doc(id).snapshots().map(
          (snap) => snap.exists ? Conversation.fromFirestore(snap) : null,
        );
  }

  /// Paged message stream. Default 30 — older pages loaded via
  /// [loadOlderMessages].
  Stream<List<ChatMessage>> streamMessages(String conversationId,
      {int limit = 30}) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromFirestore).toList());
  }

  Future<List<ChatMessage>> loadOlderMessages({
    required String conversationId,
    required DateTime before,
    int limit = 30,
  }) async {
    final snap = await _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map(ChatMessage.fromFirestore).toList();
  }

  /// Single source-of-truth stream of every conversation the user is in.
  /// Filters by `participantIds array-contains uid` so the query matches
  /// the Firestore security rule's predicate exactly — Firestore rejects
  /// list queries whose filters don't statically prove the rule is
  /// satisfied for every returned doc, which is why filtering by
  /// `customerId` / `sellerId` against a `participantIds`-based rule was
  /// failing with "Missing or insufficient permissions".
  Stream<List<Conversation>> _streamAllForUser(String uid) {
    return _conversations
        .where('participantIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Conversation.fromFirestore).toList());
  }

  /// Customer-side threads (caller is the customer). Post-filtered client
  /// side so we don't need a second Firestore listener.
  Stream<List<Conversation>> streamCustomerConversations(String customerId) {
    return _streamAllForUser(customerId)
        .map((list) =>
            list.where((c) => c.customerId == customerId).toList());
  }

  /// Seller-side threads (caller is the seller). Post-filtered client side.
  Stream<List<Conversation>> streamSellerConversations(String sellerId) {
    return _streamAllForUser(sellerId)
        .map((list) => list.where((c) => c.sellerId == sellerId).toList());
  }

  /// Batches the message write + conversation summary update so other
  /// participants get one snapshot event with everything coherent. The
  /// rule enforces `senderId == auth.uid` and the 1000-char cap.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    required bool fromCustomer,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final clipped =
        trimmed.length > 1000 ? trimmed.substring(0, 1000) : trimmed;

    final convRef = _conversations.doc(conversationId);
    final msgRef = _messagesRef(conversationId).doc();
    final batch = _firestore.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'text': clipped,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    batch.update(convRef, {
      'lastMessage': clipped,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
      // Bump the *other* party's unread count.
      if (fromCustomer)
        'unreadCountSeller': FieldValue.increment(1)
      else
        'unreadCountCustomer': FieldValue.increment(1),
    });
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('[chat] sendMessage FAIL: $e');
      rethrow;
    }
    // TODO(notifications): once Cloud Functions / FCM topics are wired,
    // mint a push notification to the other participant here.
  }

  /// Reset the viewer's unread counter when they open the thread.
  Future<void> markRead({
    required String conversationId,
    required bool isCustomer,
  }) async {
    try {
      await _conversations.doc(conversationId).update({
        if (isCustomer)
          'unreadCountCustomer': 0
        else
          'unreadCountSeller': 0,
      });
    } catch (e) {
      debugPrint('[chat] markRead soft-fail: $e');
    }
  }
}
