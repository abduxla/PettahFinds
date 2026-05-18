import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/app_constants.dart';

/// Thrown when Firebase Auth requires a fresh sign-in before allowing
/// the account delete to proceed. Caller should re-authenticate the
/// user and retry [AccountDeletionService.deleteSelf].
class RequiresRecentLoginException implements Exception {
  final String message;
  const RequiresRecentLoginException(
      [this.message =
          'Sign in again to confirm account deletion. This is a Firebase security requirement.']);

  @override
  String toString() => message;
}

/// Wipes all of a user's data from Firestore + (optionally) deletes the
/// Firebase Auth account.
///
/// Two entry points:
///   - [deleteSelf]   — current signed-in user wipes themselves. Cascades
///                      Firestore data then deletes the Firebase Auth
///                      identity. Throws [RequiresRecentLoginException]
///                      when the user must re-auth.
///   - [adminDelete]  — admin wipes another user's Firestore data. The
///                      Auth identity remains a zombie (no /users doc →
///                      app boots them on next sign-in). True Auth
///                      removal needs the Admin SDK on a backend, which
///                      this project does not have yet.
///
/// Cascade order matters: leaves first so a partial failure leaves an
/// orphan list rather than an inconsistent business. The /users doc is
/// removed LAST so the rules-based ownership check on prior steps
/// (which can read /users for role lookups) still works while the
/// cascade runs.
class AccountDeletionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AccountDeletionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Wipe the currently signed-in user's account end-to-end.
  Future<void> deleteSelf() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in.');
    }
    final uid = user.uid;

    // 1) Firestore data first. If the Auth delete fails for whatever
    //    reason (network, requires-recent-login) the user is left
    //    without Firestore data — that's acceptable because the
    //    re-auth + retry path completes the Auth step.
    await _wipeFirestoreData(uid);

    // 2) Auth identity.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Firestore is already gone; signing out keeps the app in a
        // consistent state until the caller re-auths.
        await _signOutQuietly();
        throw const RequiresRecentLoginException();
      }
      rethrow;
    }

    // Some platforms cache the Google session even after a Firebase
    // Auth user delete; nuke it so the next sign-in shows the picker.
    await _signOutQuietly();
  }

  /// Admin-side wipe of another user's data. Does NOT touch the Firebase
  /// Auth record — admin SDK is required for that and isn't deployed.
  /// After this call the target user can no longer use the app (no
  /// /users doc to load).
  Future<void> adminDelete(String uid) async {
    if (uid.isEmpty) throw Exception('Missing uid.');
    await _wipeFirestoreData(uid);
  }

  // ---------------------------------------------------------------------------
  // Re-authentication helpers — called BY the UI after a
  // RequiresRecentLoginException so a retry of deleteSelf succeeds.
  // ---------------------------------------------------------------------------

  /// True if the currently signed-in user's primary provider is Google.
  /// Drives which re-auth UI to show (password prompt vs Google picker).
  bool get currentUserIsGoogle {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData
        .any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);
  }

  /// Re-authenticate an email/password user with their password.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not signed in with an email account.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  /// Re-authenticate a Google user by re-running the Google picker.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in.');
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    await user.reauthenticateWithCredential(cred);
  }

  // ---------------------------------------------------------------------------
  // Cascade — internals
  // ---------------------------------------------------------------------------

  Future<void> _wipeFirestoreData(String uid) async {
    // -- Discover the business owned by this user (if any) ---------------
    String? businessId;
    try {
      final ownedSnap = await _firestore
          .collection(AppConstants.businessesCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (ownedSnap.docs.isNotEmpty) {
        businessId = ownedSnap.docs.first.id;
      }
    } catch (e) {
      debugPrint('[delete] business lookup failed: $e');
    }

    // -- Discover product IDs owned by the business ----------------------
    final productIds = <String>[];
    if (businessId != null) {
      try {
        final productsSnap = await _firestore
            .collection(AppConstants.productsCollection)
            .where('businessId', isEqualTo: businessId)
            .get();
        productIds.addAll(productsSnap.docs.map((d) => d.id));
      } catch (e) {
        debugPrint('[delete] product lookup failed: $e');
      }
    }

    // -- Run leaf deletes in parallel where possible ---------------------
    //
    // Each helper logs and swallows its own errors. A failure on
    // /favorites should not abort the cascade of /reviews etc — partial
    // cleanup is better than nothing. The final user doc deletion is
    // wrapped separately below.
    await Future.wait([
      _deleteWhere(AppConstants.favoritesCollection, 'userId', uid),
      _deleteWhere(AppConstants.reviewsCollection, 'userId', uid),
      _deleteWhere('productReviews', 'userId', uid),
      _deleteWhere(AppConstants.notificationsCollection, 'userId', uid),
      _deleteWhere(AppConstants.reportsCollection, 'userId', uid),
    ]);

    // -- Business cascade (if owner) -------------------------------------
    if (businessId != null) {
      // Reviews against the business
      await _deleteWhere(
          AppConstants.reviewsCollection, 'businessId', businessId);
      // Product reviews tied to those products (chunk for whereIn limit)
      for (final chunk in _chunk(productIds, 30)) {
        await _deleteWhereIn('productReviews', 'productId', chunk);
      }
      // The products themselves
      if (productIds.isNotEmpty) {
        await _deleteByIds(AppConstants.productsCollection, productIds);
      }
      // Offers tied to the business (defensive — may not be in use yet)
      await _deleteWhere(
          AppConstants.offersCollection, 'businessId', businessId);
      // The business doc itself
      try {
        await _firestore
            .collection(AppConstants.businessesCollection)
            .doc(businessId)
            .delete();
      } catch (e) {
        debugPrint('[delete] business doc delete failed: $e');
      }
    }

    // -- Conversations + nested messages ---------------------------------
    await _deleteConversationsAndMessages(uid);

    // -- Finally the user doc --------------------------------------------
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .delete();
    } catch (e) {
      debugPrint('[delete] user doc delete failed: $e');
      rethrow;
    }
  }

  /// Page size for delete sweeps. Stays under Firestore's 500-write
  /// batch ceiling AND keeps each get() response well under the
  /// per-query 10MB cap even for fat docs.
  static const _pageSize = 400;

  /// Delete every doc where [field] equals [value]. Paginates so the
  /// sweep handles unbounded match counts (thousands of favorites /
  /// reviews on a power user) without hitting the per-get() response
  /// size limit.
  Future<void> _deleteWhere(
      String collection, String field, String value) async {
    try {
      while (true) {
        final snap = await _firestore
            .collection(collection)
            .where(field, isEqualTo: value)
            .limit(_pageSize)
            .get();
        if (snap.docs.isEmpty) break;
        await _deleteRefs(snap.docs.map((d) => d.reference));
        // If we got fewer than a page, we're done. Cheaper than
        // re-issuing the query just to see an empty result.
        if (snap.docs.length < _pageSize) break;
      }
    } catch (e) {
      debugPrint('[delete] $collection where $field == $value failed: $e');
    }
  }

  /// Delete every doc where [field] is in [values]. Caller chunks
  /// [values] to <=30 to satisfy Firestore's whereIn cap; this method
  /// paginates over MATCHES (a 30-value whereIn against productReviews
  /// could still return thousands of rows on a popular merchant).
  Future<void> _deleteWhereIn(
      String collection, String field, List<String> values) async {
    if (values.isEmpty) return;
    try {
      while (true) {
        final snap = await _firestore
            .collection(collection)
            .where(field, whereIn: values)
            .limit(_pageSize)
            .get();
        if (snap.docs.isEmpty) break;
        await _deleteRefs(snap.docs.map((d) => d.reference));
        if (snap.docs.length < _pageSize) break;
      }
    } catch (e) {
      debugPrint('[delete] $collection where $field in $values failed: $e');
    }
  }

  Future<void> _deleteByIds(String collection, List<String> ids) async {
    try {
      await _deleteRefs(
          ids.map((id) => _firestore.collection(collection).doc(id)));
    } catch (e) {
      debugPrint('[delete] $collection by ids failed: $e');
    }
  }

  /// Conversations have a nested `messages` subcollection that Firestore
  /// does NOT cascade-delete when the parent doc is removed. We fetch
  /// each conversation the user participates in, wipe its messages, then
  /// delete the conversation doc. Querying both customerId AND sellerId
  /// is required because a business-owner user can appear on either side
  /// of different threads.
  Future<void> _deleteConversationsAndMessages(String uid) async {
    try {
      final customerSnap = await _firestore
          .collection('conversations')
          .where('customerId', isEqualTo: uid)
          .get();
      final sellerSnap = await _firestore
          .collection('conversations')
          .where('sellerId', isEqualTo: uid)
          .get();

      // Dedupe — the same thread can theoretically match both queries
      // for an owner chatting with their own business (edge case).
      final convIds = <String>{
        ...customerSnap.docs.map((d) => d.id),
        ...sellerSnap.docs.map((d) => d.id),
      };

      for (final convId in convIds) {
        try {
          // Paginate the messages sweep — a busy thread can have
          // thousands of messages, well past the per-get() response
          // ceiling if fetched in one shot.
          while (true) {
            final msgs = await _firestore
                .collection('conversations')
                .doc(convId)
                .collection('messages')
                .limit(_pageSize)
                .get();
            if (msgs.docs.isEmpty) break;
            await _deleteRefs(msgs.docs.map((d) => d.reference));
            if (msgs.docs.length < _pageSize) break;
          }
          await _firestore
              .collection('conversations')
              .doc(convId)
              .delete();
        } catch (e) {
          debugPrint('[delete] conv $convId failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[delete] conversations sweep failed: $e');
    }
  }

  /// Run batched deletes over an iterable of DocumentReferences. Caps
  /// each batch at 450 operations — Firestore's hard limit is 500 and a
  /// 50-op safety margin saves us if a future field-level transform is
  /// added.
  Future<void> _deleteRefs(Iterable<DocumentReference> refs) async {
    WriteBatch batch = _firestore.batch();
    var ops = 0;
    for (final ref in refs) {
      batch.delete(ref);
      ops += 1;
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  Iterable<List<T>> _chunk<T>(List<T> input, int size) sync* {
    for (var i = 0; i < input.length; i += size) {
      yield input.sublist(i, i + size > input.length ? input.length : i + size);
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* not configured / no session */}
    try {
      await _auth.signOut();
    } catch (_) {/* already signed out */}
  }
}
