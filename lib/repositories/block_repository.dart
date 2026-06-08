import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

/// User-blocking for App Store Guideline 1.2 (user-generated content
/// safety). Lets a user block another user so that the blocked user's
/// content (chat threads, reviews, listings) is removed from the
/// blocker's feed instantly, AND files a report so the developer is
/// notified of the inappropriate behaviour.
///
/// Data model: collection `blocks`, one doc per (blocker, blocked) pair
/// with a deterministic id `${blockerUid}_${blockedUid}` so blocking is
/// idempotent and unblocking is a simple delete-by-id. Each doc:
///   { blockerUid, blockedUid, createdAt }
class BlockRepository {
  final FirebaseFirestore _firestore;

  BlockRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _blocks =>
      _firestore.collection(AppConstants.blocksCollection);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(AppConstants.reportsCollection);

  static String _docId(String blockerUid, String blockedUid) =>
      '${blockerUid}_$blockedUid';

  /// Block [blockedUid] on behalf of [blockerUid].
  ///
  /// Does two things atomically-ish:
  ///   1. Writes the block doc (so the blocked user's content is
  ///      filtered out of the blocker's feed instantly — the
  ///      blockedUidsProvider stream emits the new set immediately).
  ///   2. Files a report into /reports so an admin / the developer is
  ///      notified of the inappropriate content, as required by Apple
  ///      Guideline 1.2.
  ///
  /// [reason] and [context] are optional moderation context (e.g. the
  /// conversation id or "Abusive chat messages").
  Future<void> blockUser({
    required String blockerUid,
    required String blockedUid,
    String reason = 'Blocked by user',
    String? context,
  }) async {
    if (blockerUid.isEmpty || blockedUid.isEmpty) return;
    if (blockerUid == blockedUid) return; // can't block yourself

    final blockDoc = _blocks.doc(_docId(blockerUid, blockedUid));
    await blockDoc.set({
      'blockerUid': blockerUid,
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify the developer via the existing reports pipeline (admins
    // see these in the admin Reports screen). Best-effort — a report
    // failure must not undo the block.
    try {
      final reportDoc = _reports.doc();
      await reportDoc.set({
        'id': reportDoc.id,
        'userId': blockerUid, // the reporter (rule requires == auth.uid)
        'reportedUserId': blockedUid, // who was blocked/reported
        'targetType': 'user',
        'reason': reason,
        'details': context == null || context.isEmpty
            ? 'User blocked another user.'
            : context,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Swallow — the block itself succeeded, which is the safety-
      // critical part. The report is the secondary notification.
    }
  }

  /// Remove a block (unblock). Idempotent — deleting a non-existent
  /// doc is a no-op.
  Future<void> unblockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    if (blockerUid.isEmpty || blockedUid.isEmpty) return;
    await _blocks.doc(_docId(blockerUid, blockedUid)).delete();
  }

  /// Live set of UIDs that [blockerUid] has blocked. The customer/seller
  /// chat lists, review lists, and listing feeds subtract this set so
  /// blocked content disappears the instant a block is created.
  Stream<Set<String>> streamBlockedUids(String blockerUid) {
    if (blockerUid.isEmpty) return Stream.value(const <String>{});
    return _blocks
        .where('blockerUid', isEqualTo: blockerUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => (d.data()['blockedUid'] as String?) ?? '')
            .where((s) => s.isNotEmpty)
            .toSet());
  }
}
