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
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (snap.exists) {
        txn.delete(docRef);
      } else {
        txn.set(
          docRef,
          Favorite(
            id: id,
            userId: userId,
            targetType: targetType,
            targetId: targetId,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }
    });
  }

  Stream<List<Favorite>> streamByUser(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
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
