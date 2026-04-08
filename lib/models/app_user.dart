import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'user', 'business', 'admin'
  final String? businessId;
  final bool onboardingCompleted;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.businessId,
    this.onboardingCompleted = false,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isBusiness => role == 'business';
  bool get isUser => role == 'user';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: data['role'] ?? 'user',
      businessId: data['businessId'],
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role,
        'businessId': businessId,
        'onboardingCompleted': onboardingCompleted,
        'phoneNumber': phoneNumber,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AppUser copyWith({
    String? displayName,
    String? role,
    String? businessId,
    bool? onboardingCompleted,
    String? phoneNumber,
    String? photoUrl,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        businessId: businessId ?? this.businessId,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
      );
}
