import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/category.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;

  CategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.categoriesCollection);

  Stream<List<Category>> streamActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(Category.fromFirestore).toList());
  }

  Future<List<Category>> getAll() async {
    final snap = await _ref.where('isActive', isEqualTo: true).orderBy('name').get();
    return snap.docs.map(Category.fromFirestore).toList();
  }
}
