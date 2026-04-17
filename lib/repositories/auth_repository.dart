import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';
import '../models/app_user.dart';

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

    return appUser;
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
    await _auth.signOut();
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
}
