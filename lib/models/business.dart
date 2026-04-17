import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String businessName;
  final String ownerUid;
  final String location;
  final String description;
  final String phone;
  final String email;
  final String category;
  final String logoUrl;
  final String bannerUrl;
  final bool isVerified;
  final String membershipTier;
  final double ratingAvg;
  final int ratingCount;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const Business({
    required this.id,
    required this.businessName,
    required this.ownerUid,
    required this.location,
    required this.description,
    required this.phone,
    required this.email,
    required this.category,
    this.logoUrl = '',
    this.bannerUrl = '',
    this.isVerified = false,
    this.membershipTier = 'free',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Business(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      category: data['category'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      isVerified: data['isVerified'] ?? false,
      membershipTier: data['membershipTier'] ?? 'free',
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'businessName': businessName,
        'ownerUid': ownerUid,
        'location': location,
        'description': description,
        'phone': phone,
        'email': email,
        'category': category,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'isVerified': isVerified,
        'membershipTier': membershipTier,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Business copyWith({
    String? businessName,
    String? location,
    String? description,
    String? phone,
    String? email,
    String? category,
    String? logoUrl,
    String? bannerUrl,
    bool? isVerified,
    String? membershipTier,
    double? ratingAvg,
    int? ratingCount,
    double? latitude,
    double? longitude,
  }) =>
      Business(
        id: id,
        businessName: businessName ?? this.businessName,
        ownerUid: ownerUid,
        location: location ?? this.location,
        description: description ?? this.description,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        category: category ?? this.category,
        logoUrl: logoUrl ?? this.logoUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        isVerified: isVerified ?? this.isVerified,
        membershipTier: membershipTier ?? this.membershipTier,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        ratingCount: ratingCount ?? this.ratingCount,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
      );
}
