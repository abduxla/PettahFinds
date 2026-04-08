import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/product.dart';

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.productsCollection);

  Future<Product> create(Product product) async {
    final doc = _ref.doc();
    final now = DateTime.now();
    final newProduct = Product(
      id: doc.id,
      businessId: product.businessId,
      title: product.title,
      shortTitle: product.shortTitle,
      description: product.description,
      category: product.category,
      image1Url: product.image1Url,
      image2Url: product.image2Url,
      image3Url: product.image3Url,
      image4Url: product.image4Url,
      priceLkr: product.priceLkr,
      keywords: product.keywords,
      createdAt: now,
      updatedAt: now,
    );
    await doc.set(newProduct.toMap());
    return newProduct;
  }

  Future<Product> getById(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) throw Exception('Product not found');
    return Product.fromFirestore(doc);
  }

  Future<void> update(Product product) async {
    await _ref.doc(product.id).update({
      ...product.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) async {
    await _ref.doc(id).update({'isActive': false});
  }

  Stream<List<Product>> streamByBusiness(String businessId) {
    return _ref
        .where('businessId', isEqualTo: businessId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Product.fromFirestore).toList());
  }

  /// Streams ALL products for a business (including inactive) — for manage screen.
  Stream<List<Product>> streamAllByBusiness(String businessId) {
    return _ref
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Product.fromFirestore).toList());
  }

  Stream<List<Product>> streamAll() {
    return _ref
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Product.fromFirestore).toList());
  }

  Stream<List<Product>> streamByCategory(String category) {
    return _ref
        .where('isActive', isEqualTo: true)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Product.fromFirestore).toList());
  }

  Future<List<Product>> search(String query) async {
    final lower = query.toLowerCase();
    final snap = await _ref.where('isActive', isEqualTo: true).get();
    return snap.docs
        .map(Product.fromFirestore)
        .where((p) =>
            p.title.toLowerCase().contains(lower) ||
            p.keywords.toLowerCase().contains(lower) ||
            p.category.toLowerCase().contains(lower))
        .toList();
  }
}
