import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/business_stats.dart';

/// Records customer engagement against a business and streams the totals
/// back for the seller analytics screen.
///
/// All `record*` methods are **best-effort**: they swallow errors so a
/// blocked or offline write never disrupts the customer's browsing. Writes
/// use `set(merge:true)` + `FieldValue.increment` so the stats doc is
/// created on first event and counters accumulate atomically.
///
/// Callers should skip recording when the viewer is the business owner (so
/// a seller opening their own shop doesn't inflate their numbers).
class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.businessStatsCollection);

  Future<void> _bump(String businessId, String field) async {
    if (businessId.isEmpty) return;
    try {
      await _ref.doc(businessId).set({
        field: FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — analytics must never break browsing.
    }
  }

  Future<void> recordProfileView(String businessId) =>
      _bump(businessId, 'profileViews');

  Future<void> recordProductView(String businessId) =>
      _bump(businessId, 'productViews');

  Future<void> recordChatStarted(String businessId) =>
      _bump(businessId, 'chatsStarted');

  Future<void> recordSave(String businessId) => _bump(businessId, 'saves');

  /// Live engagement totals for a business. Emits [BusinessStats.empty]
  /// until the first event lands (the doc won't exist yet).
  Stream<BusinessStats> streamStats(String businessId) {
    return _ref.doc(businessId).snapshots().map(
          (doc) =>
              doc.exists ? BusinessStats.fromFirestore(doc) : BusinessStats.empty,
        );
  }
}
