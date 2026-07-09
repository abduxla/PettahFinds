import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_tier.dart';

class Business {
  final String id;
  final String businessName;
  final String ownerUid;
  final String ownerName;
  final String ownerPhone;
  final String location;
  final String description;
  final String phone;
  final String email;
  final String whatsappNumber;
  final String category;
  final String logoUrl;
  final String bannerUrl;
  final bool isVerified;
  final double ratingAvg;
  final int ratingCount;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  /// UID of the admin who manually onboarded this business, if any.
  /// Null for businesses created by their owners through normal signup.
  /// Audit field — surfaces in moderation / payments reconciliation so a
  /// human-onboarded record never gets confused with a self-signup.
  final String? createdByAdminUid;

  /// Assigned membership level id ('listed' | 'spotlight' | 'prime' |
  /// 'elite'). Admin-only write (see Firestore rules — owners are blocked
  /// by the field allowlist). Defaults to the free floor.
  final String tier;

  /// When the assigned [tier] lapses back to the free floor. Null for the
  /// floor level (which never expires). [effectiveTier] reads this so
  /// perks downgrade automatically once the date passes — no cron needed.
  final DateTime? tierValidUntil;

  /// One of the first 50 businesses to join PetaFinds. Stamped EXCLUSIVELY
  /// by the backend (onBusinessCreated transaction / one-time backfill) —
  /// rules block clients from seeding or editing it. Permanent honor: it
  /// never expires and survives tier changes.
  final bool foundingMember;

  const Business({
    required this.id,
    required this.businessName,
    required this.ownerUid,
    this.ownerName = '',
    this.ownerPhone = '',
    required this.location,
    required this.description,
    required this.phone,
    required this.email,
    this.whatsappNumber = '',
    required this.category,
    this.logoUrl = '',
    this.bannerUrl = '',
    this.isVerified = false,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.createdByAdminUid,
    this.tier = 'listed',
    this.tierValidUntil,
    this.foundingMember = false,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// The level an admin assigned, ignoring expiry. Use this in admin UI
  /// to show "Prime (expired)"; use [effectiveTier] everywhere perks are
  /// actually applied.
  BusinessTier get assignedTier => BusinessTier.fromId(tier);

  /// The level whose perks are *currently* in force. A paid level reverts
  /// to [BusinessTier.listed] once [tierValidUntil] passes (or if it was
  /// never set), so listing caps / placement / badges all lapse on their
  /// own with no background job.
  BusinessTier get effectiveTier {
    final assigned = assignedTier;
    if (!assigned.isPaid) return assigned;
    if (tierValidUntil == null) return BusinessTier.listed;
    return DateTime.now().isBefore(tierValidUntil!)
        ? assigned
        : BusinessTier.listed;
  }

  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Business(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerPhone: data['ownerPhone'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      whatsappNumber: data['whatsappNumber'] ?? '',
      category: data['category'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      isVerified: data['isVerified'] ?? false,
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByAdminUid: data['createdByAdminUid'] as String?,
      tier: data['tier'] as String? ?? 'listed',
      tierValidUntil: (data['tierValidUntil'] as Timestamp?)?.toDate(),
      foundingMember: data['foundingMember'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'businessName': businessName,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'location': location,
        'description': description,
        'phone': phone,
        'email': email,
        'whatsappNumber': whatsappNumber,
        'category': category,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'isVerified': isVerified,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': Timestamp.fromDate(createdAt),
        if (createdByAdminUid != null) 'createdByAdminUid': createdByAdminUid,
        'tier': tier,
        if (tierValidUntil != null)
          'tierValidUntil': Timestamp.fromDate(tierValidUntil!),
        // Deliberately NOT serialized: foundingMember is backend-stamped
        // only; a client create/update must never carry it (rules reject).
      };

  Business copyWith({
    String? businessName,
    String? ownerName,
    String? ownerPhone,
    String? location,
    String? description,
    String? phone,
    String? email,
    String? whatsappNumber,
    String? category,
    String? logoUrl,
    String? bannerUrl,
    bool? isVerified,
    double? ratingAvg,
    int? ratingCount,
    double? latitude,
    double? longitude,
    String? tier,
    DateTime? tierValidUntil,
  }) =>
      Business(
        id: id,
        businessName: businessName ?? this.businessName,
        ownerUid: ownerUid,
        ownerName: ownerName ?? this.ownerName,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        location: location ?? this.location,
        description: description ?? this.description,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        category: category ?? this.category,
        logoUrl: logoUrl ?? this.logoUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        isVerified: isVerified ?? this.isVerified,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        ratingCount: ratingCount ?? this.ratingCount,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
        createdByAdminUid: createdByAdminUid,
        tier: tier ?? this.tier,
        tierValidUntil: tierValidUntil ?? this.tierValidUntil,
        // Backend-owned honor — always carried through, never a param.
        foundingMember: foundingMember,
      );
}
