import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/business.dart';

class BusinessRepository {
  final FirebaseFirestore _firestore;

  BusinessRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.businessesCollection);

  Future<Business> create(Business business) async {
    final doc = _ref.doc();
    final newBusiness = Business(
      id: doc.id,
      businessName: business.businessName,
      ownerUid: business.ownerUid,
      location: business.location,
      description: business.description,
      phone: business.phone,
      email: business.email,
      category: business.category,
      logoUrl: business.logoUrl,
      bannerUrl: business.bannerUrl,
      createdAt: DateTime.now(),
    );
    await doc.set(newBusiness.toMap());
    return newBusiness;
  }

  Future<Business> getById(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) throw Exception('Business not found');
    return Business.fromFirestore(doc);
  }

  Future<Business?> getByOwnerUid(String uid) async {
    final snap =
        await _ref.where('ownerUid', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Business.fromFirestore(snap.docs.first);
  }

  Future<void> update(Business business) async {
    await _ref.doc(business.id).update(business.toMap());
  }

  Future<void> toggleVerification(String id, bool verified) async {
    await _ref.doc(id).update({'isVerified': verified});
  }

  Stream<List<Business>> streamAll() {
    return _ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  Stream<List<Business>> streamByCategory(String category) {
    return _ref
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  Stream<List<Business>> streamVerified() {
    return _ref
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  /// Substring search over name / category / location.
  ///
  /// NOTE: Firestore has no native substring search. To keep cost bounded
  /// we cap the scan at the most recent [_searchScanLimit] businesses and
  /// filter in memory. Swap to Algolia / Typesense once the directory
  /// grows past a few thousand entries.
  static const _searchScanLimit = 200;

  Future<List<Business>> search(String query) async {
    final lower = query.toLowerCase();
    final snap = await _ref
        .orderBy('createdAt', descending: true)
        .limit(_searchScanLimit)
        .get();
    return snap.docs
        .map(Business.fromFirestore)
        .where((b) =>
            b.businessName.toLowerCase().contains(lower) ||
            b.category.toLowerCase().contains(lower) ||
            b.location.toLowerCase().contains(lower))
        .toList();
  }
}
