import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  /// OAuth ONLY — drives the Google sign-in sheet, exchanges tokens,
  /// signs in to Firebase Auth, returns the Firebase [User]. Does NOT
  /// touch /users/{uid}.
  ///
  /// Use this from BOTH the Sign-Up and Sign-In screens. Caller is
  /// responsible for the post-OAuth flow: check if /users/{uid}
  /// exists, show the role picker for first-time users, and call
  /// [seedAppUserIfMissing] with the chosen role. The Sign-Up and
  /// Sign-In screens share this exact sequence (see their
  /// _continueWithOAuth methods).
  Future<User> authenticateWithGoogle() async {
    debugPrint('🟣 [auth] authenticateWithGoogle: start (web=$kIsWeb)');
    // Web and native are two completely different flows. Both branches
    // converge on the same Firebase Auth credential — only how the
    // credential is obtained differs.
    final UserCredential cred;
    try {
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        debugPrint(
            '🟣 [auth] GoogleSignIn.signIn returned ${googleUser?.email ?? "null"}');
        if (googleUser == null) {
          throw Exception('Google sign-in cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }
      debugPrint(
          '🟢 [auth] authenticateWithGoogle: signed in uid=${cred.user?.uid}');
    } catch (e) {
      debugPrint('🔴 [auth] Google Sign-In error: $e');
      final s = e.toString();
      if (s.contains('popup-closed-by-user') ||
          s.contains('cancelled')) {
        throw Exception('Google sign-in cancelled.');
      }
      if (s.contains('account-exists-with-different-credential')) {
        throw Exception(
            'An account already exists with this email. Sign in with the original method.');
      }
      throw Exception(
          'Google sign-in failed. Please try again or use another method.');
    }
    return cred.user!;
  }

  /// Returns the existing AppUser doc, or seeds one with [role] +
  /// metadata pulled off the Firebase user. Idempotent — calling
  /// twice with the same uid returns the same doc the second time.
  ///
  /// Mints the welcome in-app notification only on the FIRST seed
  /// (subsequent calls short-circuit because the doc already exists).
  ///
  /// [role] is the role to write if the doc is missing. Existing docs
  /// keep their stored role regardless of what's passed.
  Future<AppUser> seedAppUserIfMissing({
    required User firebaseUser,
    required String role,
  }) async {
    final userDoc = _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid);
    final snap = await userDoc.get();
    if (snap.exists) {
      debugPrint(
          '[auth] seedAppUserIfMissing: doc already exists for ${firebaseUser.uid} — returning stored role');
      return AppUser.fromFirestore(snap);
    }

    final safeRole =
        _allowedSignupRoles.contains(role) ? role : 'user';

    final appUser = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName:
          (firebaseUser.displayName ?? 'PetaFinds user').trim(),
      role: safeRole,
      photoUrl: firebaseUser.photoURL ?? '',
      createdAt: DateTime.now(),
    );
    try {
      await userDoc.set(appUser.toMap());
      // Visible-in-DevTools confirmation that the doc actually landed
      // with the expected role. The post-F1 "Something went wrong"
      // bug surfaced as silent doc-creation failure; logging both
      // success and failure here makes any future regression
      // self-diagnosing on the very first failed sign-up.
      debugPrint(
          '[auth] seedAppUserIfMissing: /users/${firebaseUser.uid} created with role=$safeRole');
    } catch (e) {
      debugPrint(
          '[auth] seedAppUserIfMissing FAILED for ${firebaseUser.uid} (role=$safeRole): $e');
      rethrow;
    }

    // Best-effort welcome notification. Same pattern as email signup.
    try {
      await NotificationRepository(firestore: _firestore).createForSelf(
        userId: firebaseUser.uid,
        title: 'Welcome to PetaFinds',
        body: safeRole == 'business'
            ? 'Finish setting up your business so customers can find you.'
            : 'Browse Pettah\'s wholesale shops, save favorites, and chat with sellers on WhatsApp.',
      );
    } catch (e) {
      debugPrint('[auth] welcome notification (oauth) failed: $e');
    }
    return appUser;
  }

  // signInWithGoogle() (the convenience wrapper that called
  // seedAppUserIfMissing with role:'user') was REMOVED. It silently
  // registered first-time Google users as customers without ever
  // showing the role picker — a critical bug for anyone intending to
  // sign up as a business via the Sign-In screen.
  //
  // The Sign-In and Sign-Up screens BOTH now use the lower-level
  // [authenticateWithGoogle] + role-picker + [seedAppUserIfMissing]
  // pattern, so role assignment requires an explicit user choice on
  // first-time OAuth. There is no longer any code path in the app
  // that writes `role: 'user'` without the user picking it.
  //
  // Returning Google users hit [authenticateWithGoogle] +
  // [getAppUser] in the screen, which returns the existing doc with
  // its stored role; the picker only renders when /users/{uid} is
  // genuinely missing.

  /// Sign in with Apple (iOS native).
  ///
  /// Flow:
  ///  1. Trigger Apple's native sheet via [SignInWithApple].
  ///  2. Build a Firebase OAuthCredential from the identity token +
  ///     authorization code.
  ///  3. Sign in to Firebase Auth.
  ///  4. On first sign-in, seed an AppUser doc with role 'user' +
  ///     mint the welcome notification (mirrors signUp / Google).
  ///  5. Apple only sends givenName + familyName on the FIRST
  ///     sign-in — cache it onto the Firebase user's displayName so
  ///     subsequent sessions don't lose the name.
  ///
  /// Console setup required:
  ///  - Firebase Console → Authentication → Sign-in method → enable
  ///    Apple (provide the Services ID + Team ID).
  ///  - Xcode → Runner target → Signing & Capabilities →
  ///    + Capability → Sign in with Apple.
  ///  - Apple Developer portal: the App ID must have the
  ///    "Sign in with Apple" capability enabled.
  /// OAuth ONLY — drives Apple's native sheet, exchanges tokens,
  /// signs in to Firebase Auth, and caches the first-sign-in name
  /// onto the Firebase user's displayName. Does NOT touch
  /// /users/{uid}. Used by BOTH Sign-Up and Sign-In screens; the
  /// caller is responsible for the role-picker + seed sequence (see
  /// [authenticateWithGoogle]'s docstring for the shared pattern).
  Future<User> authenticateWithApple() async {
    debugPrint('🟣 [auth] authenticateWithApple: start');
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final cred = await _auth.signInWithCredential(oauthCredential);
    final user = cred.user!;
    debugPrint('🟢 [auth] authenticateWithApple: signed in uid=${user.uid}');

    // FIRST-SIGN-IN NAME QUIRK. Apple's privacy model only sends
    // givenName+familyName when the user authorizes the app for the
    // first time; subsequent sign-ins return null. We have exactly
    // one shot to capture them, so write through to the Firebase
    // user's displayName before anything downstream reads it.
    final fullName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty &&
        (user.displayName == null || user.displayName!.isEmpty)) {
      try {
        await user.updateDisplayName(fullName);
      } catch (e) {
        debugPrint('[auth] apple displayName update failed: $e');
      }
    }
    return user;
  }

  // signInWithApple() was REMOVED for the same reason as
  // signInWithGoogle above — hardcoded role:'user' bypassed the
  // role picker for first-time Apple sign-ups, so anyone intending
  // to sign up as a business via the Sign-In screen was silently
  // locked into a customer account. Callers now use
  // [authenticateWithApple] + role picker + [seedAppUserIfMissing]
  // explicitly. See the comment above the deleted signInWithGoogle
  // block for the full rationale.

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
