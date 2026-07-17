import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String businessId;
  final String title;
  final String shortTitle;
  final String description;
  final String category;
  final String image1Url;
  final String image2Url;
  final String image3Url;
  final String image4Url;
  /// Retail unit price. OPTIONAL — some vendors prefer not to publish
  /// prices; `null` (or a legacy 0) renders as "Ask for price" and buyers
  /// use chat instead. The historical field name stays `priceLkr` so old
  /// docs round-trip unchanged.
  final double? priceLkr;
  /// Selling unit label for goods priced per measure — e.g. "Meter",
  /// "Litre", "Roll", "Kg". Empty = priced per item (the default). When
  /// set, the price renders as "LKR 950 / Meter". Optional; only shops
  /// that sell fabrics, liquids etc. need it.
  final String unit;
  /// Per-unit wholesale price for bulk orders. `0` = not offered; the
  /// detail screen then hides the wholesale row entirely.
  final double wholesalePriceLkr;
  /// Minimum order quantity (units) required to qualify for
  /// [wholesalePriceLkr]. `0` = not offered. Treated as paired with
  /// `wholesalePriceLkr`: the form rejects half-configured states.
  final int minOrderQuantity;
  final String keywords;
  final bool isActive;
  /// When the OWNER pinned this product to lead their storefront
  /// (Vibranium perk). `null` = not pinned. The customer-facing shop
  /// page sorts pinned products first (most recently pinned leading);
  /// everything else keeps the normal newest-first order. Stored as a
  /// timestamp rather than a bool so the owner's pin ORDER is stable.
  final DateTime? pinnedAt;
  /// Per-product rating aggregate, mirrors the business rating fields.
  /// Bumped incrementally by `ProductReviewRepository` so the UI never
  /// has to scan the whole reviews collection.
  final double ratingAvg;
  final int ratingCount;
  /// Lifetime view count, denormalized onto the doc once a night by the
  /// nightlyMarketAggregation Cloud Function so customer discovery
  /// surfaces can rank by popularity without reading the owner-only
  /// product_stats collection. BACKEND-OWNED: deliberately absent from
  /// [toMap] and blocked in the products update rule, so client writes
  /// can never touch it. Coarse by design — ranking uses views as a
  /// refinement within a tier band, so nightly freshness is plenty.
  final int rankViews;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.businessId,
    required this.title,
    this.shortTitle = '',
    required this.description,
    required this.category,
    this.image1Url = '',
    this.image2Url = '',
    this.image3Url = '',
    this.image4Url = '',
    this.priceLkr,
    this.unit = '',
    this.wholesalePriceLkr = 0.0,
    this.minOrderQuantity = 0,
    this.keywords = '',
    this.isActive = true,
    this.pinnedAt,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.rankViews = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get imageUrls =>
      [image1Url, image2Url, image3Url, image4Url]
          .where((url) => url.isNotEmpty)
          .toList();

  /// True only when both wholesale fields are populated. The detail
  /// screen uses this to decide whether to render the two-tier pricing
  /// block; the form treats them as a paired pair (both or neither).
  bool get hasWholesaleTier =>
      wholesalePriceLkr > 0 && minOrderQuantity > 0;

  /// Whether a publishable retail price exists. Legacy docs that stored
  /// 0 are treated as price-on-request too (nothing legitimately costs
  /// LKR 0 in the directory).
  bool get hasPrice => priceLkr != null && priceLkr! > 0;

  bool get isPinned => pinnedAt != null;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      title: data['title'] ?? '',
      shortTitle: data['shortTitle'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      image1Url: data['image1Url'] ?? '',
      image2Url: data['image2Url'] ?? '',
      image3Url: data['image3Url'] ?? '',
      image4Url: data['image4Url'] ?? '',
      priceLkr: (data['priceLkr'] as num?)?.toDouble(),
      unit: data['unit'] ?? '',
      wholesalePriceLkr:
          (data['wholesalePriceLkr'] ?? 0.0).toDouble(),
      minOrderQuantity:
          (data['minOrderQuantity'] as num?)?.toInt() ?? 0,
      keywords: data['keywords'] ?? '',
      isActive: data['isActive'] ?? true,
      pinnedAt: (data['pinnedAt'] as Timestamp?)?.toDate(),
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      rankViews: (data['rankViews'] as num?)?.toInt() ?? 0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'businessId': businessId,
        'title': title,
        'shortTitle': shortTitle,
        'description': description,
        'category': category,
        'image1Url': image1Url,
        'image2Url': image2Url,
        'image3Url': image3Url,
        'image4Url': image4Url,
        'priceLkr': priceLkr,
        'unit': unit,
        'wholesalePriceLkr': wholesalePriceLkr,
        'minOrderQuantity': minOrderQuantity,
        'keywords': keywords,
        'isActive': isActive,
        'pinnedAt':
            pinnedAt != null ? Timestamp.fromDate(pinnedAt!) : null,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Sentinel so copyWith can distinguish "not passed" from an explicit
  /// `null` (vendor clearing a previously-published price).
  static const Object _unsetPrice = Object();

  Product copyWith({
    String? title,
    String? shortTitle,
    String? description,
    String? category,
    String? image1Url,
    String? image2Url,
    String? image3Url,
    String? image4Url,
    Object? priceLkr = _unsetPrice,
    String? unit,
    double? wholesalePriceLkr,
    int? minOrderQuantity,
    String? keywords,
    bool? isActive,
    double? ratingAvg,
    int? ratingCount,
  }) =>
      Product(
        id: id,
        businessId: businessId,
        title: title ?? this.title,
        shortTitle: shortTitle ?? this.shortTitle,
        description: description ?? this.description,
        category: category ?? this.category,
        image1Url: image1Url ?? this.image1Url,
        image2Url: image2Url ?? this.image2Url,
        image3Url: image3Url ?? this.image3Url,
        image4Url: image4Url ?? this.image4Url,
        priceLkr: identical(priceLkr, _unsetPrice)
            ? this.priceLkr
            : priceLkr as double?,
        unit: unit ?? this.unit,
        wholesalePriceLkr: wholesalePriceLkr ?? this.wholesalePriceLkr,
        minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
        keywords: keywords ?? this.keywords,
        isActive: isActive ?? this.isActive,
        pinnedAt: pinnedAt,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        ratingCount: ratingCount ?? this.ratingCount,
        rankViews: rankViews,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
