import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/favorite.dart';

class FavoriteRepository {
  final FirebaseFirestore _firestore;

  FavoriteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.favoritesCollection);

  /// Deterministic doc id keeps `(user, target)` unique without a query +
  /// transaction. Double-taps map to the same doc, so the worst case is
  /// "toggled twice" (back to start), not duplicate favorite rows.
  String _favoriteId({
    required String userId,
    required String targetType,
    required String targetId,
  }) =>
      '${userId}_${targetType}_$targetId';

  /// Toggle a favorite: read once, then write the opposite. The previous
  /// implementation wrapped this in a transaction, which broke first-time
  /// favorites because Firestore evaluates the read rule even on the
  /// pre-write `get` of a non-existent doc (`resource` is null, and a rule
  /// that references `resource.data` denies it). The companion rule fix in
  /// `firebase/firestore.rules` authorizes reads by the deterministic
  /// `${uid}_*` id prefix so the missing-doc `get` returns "not exists"
  /// cleanly. Doc IDs are deterministic so we don't need the transaction's
  /// atomicity — the worst case for a double-tap is "toggled twice back to
  /// start", not duplicate rows.
  Future<void> toggle({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final id = _favoriteId(
      userId: userId,
      targetType: targetType,
      targetId: targetId,
    );
    final docRef = _ref.doc(id);
    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
    } else {
      await docRef.set(
        Favorite(
          id: id,
          userId: userId,
          targetType: targetType,
          targetId: targetId,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    }
  }

  /// Caps the favorites stream. 200 newest is far more than any user is
  /// expected to keep; protects cost on power users without changing the
  /// favorites screen UX.
  static const _streamLimit = 200;

  Stream<List<Favorite>> streamByUser(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Favorite.fromFirestore).toList());
  }

  Future<bool> isFavorite({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final id = _favoriteId(
      userId: userId,
      targetType: targetType,
      targetId: targetId,
    );
    final snap = await _ref.doc(id).get();
    return snap.exists;
  }
}
