import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'notification_repository.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Roles the client is ever allowed to self-assign. 'admin' is intentionally
  // excluded — admin is granted via Firebase Auth custom claims by a trusted
  // backend, never by the client.
  static const _allowedSignupRoles = {'user', 'business'};

  // Profile fields a user may update about themselves. role / email / uid /
  // createdAt are all frozen at the repository level so we never accidentally
  // hand the server a payload that tries to mutate them.
  static const _selfMutableFields = {
    'displayName',
    'phoneNumber',
    'photoUrl',
    'onboardingCompleted',
    'businessId',
  };

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    String role = 'user',
  }) async {
    final safeRole = _allowedSignupRoles.contains(role) ? role : 'user';

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());

    // Send verification email. Sign-in is intentionally NOT gated on
    // emailVerified yet — that would break existing accounts. The link
    // gives accountability for new signups; tighten later via a soft
    // banner / hard gate in a separate change.
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Don't let a transient mail-send failure block the signup.
    }

    final appUser = AppUser(
      uid: user.uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: safeRole,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(appUser.toMap());

    // Seed the inbox with a welcome message so the bell + notifications
    // screen aren't empty on first run. Best-effort: a failure here must
    // not roll back signup.
    try {
      await NotificationRepository(firestore: _firestore).createForSelf(
        userId: user.uid,
        title: 'Welcome to PetaFinds',
        body: safeRole == 'business'
            ? 'Finish setting up your business so customers can find you.'
            : 'Browse Pettah\'s wholesale shops, save favorites, and chat with sellers on WhatsApp.',
      );
    } catch (e) {
      // Best-effort. Most likely cause once App Check is enforced is a
      // missing debug token in dev. Log so it's visible in DevTools but
      // never roll back signup over a missing welcome card.
      debugPrint('[auth] welcome notification failed: $e');
    }

    return appUser;
  }

  /// Resend the verification email for the currently-signed-in user.
  /// Call from a "verify your email" banner.
  Future<void> resendEmailVerification() async {
    final u = _auth.currentUser;
    if (u != null && !u.emailVerified) {
      await u.sendEmailVerification();
    }
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return getAppUser(cred.user!.uid);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    // Google session is signed out separately so the next Google sign-in
    // shows the account picker again rather than silently re-using the
    // last token. Firebase sign-out alone leaves the GoogleSignIn cache
    // behind, which surprises users sharing a device.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // No Google session active, or platform not configured — ignore.
    }
    await _auth.signOut();
  }

  /// One-tap Google sign-in. Flow:
  ///  1. Trigger native Google account picker.
  ///  2. Exchange the Google ID + access tokens for a Firebase credential.
  ///  3. On first sign-in (no users/{uid} doc), seed an AppUser with role
  ///     "user" so the rest of the app treats them as a regular customer.
  ///     Business signup stays email/password — role escalation isn't
  ///     supported through this flow.
  ///
  /// Console setup required (one-time, per platform):
  ///  - Firebase Console → Authentication → Sign-in method → enable Google.
  ///  - Android: add the app's SHA-1 (and SHA-256 for release) in Project
  ///    Settings → Your apps → Android → Add fingerprint. Then re-download
  ///    google-services.json and drop it into android/app/.
  ///  - iOS: copy `REVERSED_CLIENT_ID` from the new GoogleService-Info.plist
  ///    into ios/Runner/Info.plist as a CFBundleURLSchemes entry.
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // User cancelled the picker — bubble a tame error so the sign-in
      // screen can surface a snackbar instead of a stack trace.
      throw Exception('Google sign-in cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user!;

    final userDoc = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);
    final snap = await userDoc.get();
    if (snap.exists) {
      return AppUser.fromFirestore(snap);
    }

    // First sign-in via Google — seed the AppUser doc. Display name and
    // photo come from the Google profile; falls back gracefully if Google
    // didn't provide them.
    final appUser = AppUser(
      uid: user.uid,
      email: user.email ?? googleUser.email,
      displayName:
          (user.displayName ?? googleUser.displayName ?? 'PetaFinds user')
              .trim(),
      role: 'user',
      photoUrl: user.photoURL ?? '',
      createdAt: DateTime.now(),
    );
    await userDoc.set(appUser.toMap());

    // Best-effort welcome notification, same pattern as email signup.
    try {
      await NotificationRepository(firestore: _firestore).createForSelf(
        userId: user.uid,
        title: 'Welcome to PetaFinds',
        body:
            'Browse Pettah\'s wholesale shops, save favorites, and chat with sellers.',
      );
    } catch (e) {
      debugPrint('[auth] welcome notification (google) failed: $e');
    }
    return appUser;
  }

  Future<AppUser> getAppUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) {
      throw Exception('User document not found');
    }
    return AppUser.fromFirestore(doc);
  }

  /// Updates only the self-mutable profile fields. role / email / createdAt
  /// are never sent from the client — even if the caller tries. This matches
  /// the Firestore rule which rejects any diff that touches other fields.
  Future<void> updateUser(AppUser user) async {
    final full = user.toMap();
    final safe = <String, dynamic>{
      for (final key in _selfMutableFields)
        if (full.containsKey(key)) key: full[key],
    };
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(safe);
  }

  Stream<AppUser?> streamAppUser(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  /// Look up a user by their email address. Returns null if no AppUser
  /// document exists. Email match is case-insensitive (we normalize on
  /// signup, but legacy docs may carry mixed case — we search both ways
  /// and take whichever hits).
  ///
  /// Used by the admin onboarding flow to bind a manually-created
  /// business to an existing customer account.
  Future<AppUser?> findByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final col = _firestore.collection(AppConstants.usersCollection);

    var snap = await col.where('email', isEqualTo: normalized).limit(1).get();
    if (snap.docs.isNotEmpty) return AppUser.fromFirestore(snap.docs.first);

    // Fallback for legacy docs that stored email in its as-typed casing.
    snap = await col.where('email', isEqualTo: email.trim()).limit(1).get();
    if (snap.docs.isNotEmpty) return AppUser.fromFirestore(snap.docs.first);

    return null;
  }

  /// Admin-only: promote a user to business role and bind them to a
  /// business doc. Bypasses [_selfMutableFields] because the admin is
  /// editing another user's record, not their own. The Firestore
  /// `isAdmin()` rule enforces this at the server — a non-admin caller
  /// will be rejected with permission-denied even if they invoke this.
  ///
  /// Sets `onboardingCompleted: true` because admin onboarding is the
  /// completion event — the user shouldn't be funneled into the setup
  /// wizard on next sign-in.
  Future<void> adminAssignBusinessToUser({
    required String uid,
    required String businessId,
  }) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
      'role': 'business',
      'businessId': businessId,
      'onboardingCompleted': true,
    });
  }
}
