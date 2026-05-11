import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.notificationsCollection);

  /// Mints a notification addressed to the caller. Firestore rules allow
  /// self-create only — `userId` MUST match `request.auth.uid` or the
  /// write is rejected. Used at signup to seed the inbox so the bell
  /// surface isn't empty out of the box.
  Future<void> createForSelf({
    required String userId,
    required String title,
    required String body,
  }) async {
    final doc = _ref.doc();
    await doc.set({
      'id': doc.id,
      'userId': userId,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Caps the notifications stream. Older items are still in Firestore;
  /// "show more" can paginate later. 100 newest is plenty for the bell.
  static const _streamLimit = 100;

  Stream<List<AppNotification>> streamByUser(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppNotification.fromFirestore).toList());
  }

  Future<void> markAsRead(String id) async {
    await _ref.doc(id).update({'read': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _ref
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
