import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/business.dart';
import '../models/business_tier.dart';

class BusinessRepository {
  final FirebaseFirestore _firestore;

  BusinessRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.businessesCollection);

  Future<Business> create(Business business) async {
    final doc = _ref.doc();
    // Earlier this method enumerated only a subset of fields and
    // silently dropped whatsappNumber, isVerified, createdByAdminUid,
    // lat/long, and ratings. That broke admin auto-verify onboarding
    // (isVerified was always reset to false) and the self-signup form
    // (WhatsApp number filled in by the merchant never persisted).
    // Now we preserve every field the caller passed, only forcing the
    // server-side id + createdAt.
    final newBusiness = Business(
      id: doc.id,
      businessName: business.businessName,
      ownerUid: business.ownerUid,
      location: business.location,
      description: business.description,
      phone: business.phone,
      email: business.email,
      whatsappNumber: business.whatsappNumber,
      category: business.category,
      logoUrl: business.logoUrl,
      bannerUrl: business.bannerUrl,
      isVerified: business.isVerified,
      ratingAvg: business.ratingAvg,
      ratingCount: business.ratingCount,
      latitude: business.latitude,
      longitude: business.longitude,
      createdAt: DateTime.now(),
      createdByAdminUid: business.createdByAdminUid,
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

  Stream<Business?> streamById(String id) {
    return _ref.doc(id).snapshots().map(
          (doc) => doc.exists ? Business.fromFirestore(doc) : null,
        );
  }

  Future<void> update(Business business) async {
    await _ref.doc(business.id).update(business.toMap());
  }

  Future<void> toggleVerification(String id, bool verified) async {
    await _ref.doc(id).update({'isVerified': verified});
  }

  /// Assign a membership level to a business. Admin-only at the rules
  /// layer (the owner field allowlist excludes `tier`/`tierValidUntil`,
  /// so this only succeeds via the `isAdmin()` branch).
  ///
  /// [validUntil] is when a *paid* level lapses back to the free floor —
  /// typically the end of the paid period. For the floor level (or a null
  /// date) the expiry field is cleared. [Business.effectiveTier] enforces
  /// the downgrade client-side, so no scheduled job is required.
  Future<void> setTier(
    String id,
    BusinessTier tier, {
    DateTime? validUntil,
  }) async {
    await _ref.doc(id).update({
      'tier': tier.id,
      'tierValidUntil': (!tier.isPaid || validUntil == null)
          ? FieldValue.delete()
          : Timestamp.fromDate(validUntil),
    });
  }

  /// Verified businesses on a paid membership level, for the home-screen
  /// "Featured" strip. The main directory/search lists stay by relevance —
  /// featuring lives only in this dedicated strip so no single shop ever
  /// dominates the regular browsing order.
  ///
  /// Rotated by a slowly-advancing time offset (≈1-minute steps) so each
  /// featured shop cycles through the front fairly rather than the same
  /// shop always leading. [Business.effectiveTier] accounts for expiry, so
  /// a lapsed level silently drops out of the strip.
  ///
  /// Caveat: capped at [_streamLimit] most-recent docs; a featured shop
  /// older than that window won't surface until paging lands. Fine at the
  /// current directory size.
  Stream<List<Business>> streamFeatured() {
    return _ref
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) {
      final paid = snap.docs
          .map(Business.fromFirestore)
          .where((b) => b.effectiveTier.isPaid)
          .toList();
      if (paid.length <= 1) return paid;
      final offset =
          (DateTime.now().millisecondsSinceEpoch ~/ 60000) % paid.length;
      return [...paid.sublist(offset), ...paid.sublist(0, offset)];
    });
  }

  /// Caps the live stream of businesses. Same rationale as
  /// [ProductRepository._streamLimit] — protects cost; pageable later.
  static const _streamLimit = 100;

  /// Customer-facing list — verified only. Unverified listings are
  /// hidden from public surfaces until an admin approves them in the
  /// admin shell. Owners still see their own unverified business via
  /// [getById] (the Firestore rule permits owner reads on their own
  /// doc).
  ///
  /// To list unverified docs too (admin moderation queue), use
  /// [streamAllIncludingPending].
  Stream<List<Business>> streamAll() {
    return _ref
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  /// Admin-only stream of every business doc, verified or not. The
  /// Firestore rule requires `isAdmin()` for non-verified reads, so
  /// calling this from a non-admin client will return permission-denied.
  Stream<List<Business>> streamAllIncludingPending() {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  /// Admin-only stream of unverified businesses awaiting review.
  /// Powers the Pending tab in the admin Businesses screen.
  Stream<List<Business>> streamPending() {
    return _ref
        .where('isVerified', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  Stream<List<Business>> streamByCategory(String category) {
    return _ref
        .where('category', isEqualTo: category)
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Business.fromFirestore).toList());
  }

  Stream<List<Business>> streamVerified() {
    return _ref
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(_streamLimit)
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
    // Customer-facing — verified only. Server-side filter keeps the
    // scan budget honest (we still cap at _searchScanLimit).
    final snap = await _ref
        .where('isVerified', isEqualTo: true)
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
