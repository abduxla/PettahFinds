import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

/// Follows = subscriptions to a business's updates.
///
/// Distinct from favorites: favouriting a business is a *private bookmark*
/// (the heart button), whereas following opts the user into push + in-app
/// notifications. When a followed business posts a new product or drops a
/// price, the server-side Cloud Functions (`onProductCreated` /
/// `onProductPublished` / `onProductPriceDrop`) fan a notification out to
/// every follower.
///
/// Mirrors [FavoriteRepository]'s deterministic-id pattern: the doc id is
/// `${userId}_$businessId`, so a double-tap is idempotent (worst case:
/// toggled twice, back to the start) and no transaction is needed. Each
/// doc holds `{ userId, businessId, createdAt }`; the Cloud Function reads
/// `where('businessId', ==)` to find who to notify.
class FollowRepository {
  final FirebaseFirestore _firestore;

  FollowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.followsCollection);

  String _followId(String userId, String businessId) =>
      '${userId}_$businessId';

  /// Follow if not already following, otherwise unfollow. Returns the new
  /// state (`true` == now following) so the caller can show the right
  /// snackbar without a re-read.
  Future<bool> toggle({
    required String userId,
    required String businessId,
  }) async {
    final docRef = _ref.doc(_followId(userId, businessId));
    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
      return false;
    }
    await docRef.set({
      'userId': userId,
      'businessId': businessId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return true;
  }

  Future<bool> isFollowing({
    required String userId,
    required String businessId,
  }) async {
    final snap = await _ref.doc(_followId(userId, businessId)).get();
    return snap.exists;
  }

  /// Generous cap — following hundreds of shops is far beyond expected use,
  /// but the limit protects read cost on the odd power user.
  static const _streamLimit = 300;

  /// Live list of the businessIds this user follows, newest-first. Backs
  /// both the Following screen and every Follow button's state.
  ///
  /// Deliberately a single-field equality query (no `orderBy`) so it needs
  /// no composite index; ordering is done client-side over the (small)
  /// result set.
  Stream<List<String>> streamFollowedBusinessIds(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ma = a.data() as Map<String, dynamic>;
          final mb = b.data() as Map<String, dynamic>;
          final ta = ma['createdAt'];
          final tb = mb['createdAt'];
          final da = ta is Timestamp ? ta.toDate() : DateTime(1970);
          final db = tb is Timestamp ? tb.toDate() : DateTime(1970);
          return db.compareTo(da);
        });
      return docs
          .map((d) =>
              (d.data() as Map<String, dynamic>)['businessId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    });
  }
}
