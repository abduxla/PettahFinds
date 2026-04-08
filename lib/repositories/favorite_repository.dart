import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/favorite.dart';

class FavoriteRepository {
  final FirebaseFirestore _firestore;

  FavoriteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.favoritesCollection);

  Future<void> toggle({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final snap = await _ref
        .where('userId', isEqualTo: userId)
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
    } else {
      final doc = _ref.doc();
      await doc.set(Favorite(
        id: doc.id,
        userId: userId,
        targetType: targetType,
        targetId: targetId,
        createdAt: DateTime.now(),
      ).toMap());
    }
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
    final snap = await _ref
        .where('userId', isEqualTo: userId)
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
