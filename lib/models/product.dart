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
  /// Retail unit price. Always shown to customers and falls back as the
  /// only displayed price when wholesale isn't configured. The historical
  /// field name stays `priceLkr` so old docs round-trip unchanged.
  final double priceLkr;
  /// Per-unit wholesale price for bulk orders. `0` = not offered; the
  /// detail screen then hides the wholesale row entirely.
  final double wholesalePriceLkr;
  /// Minimum order quantity (units) required to qualify for
  /// [wholesalePriceLkr]. `0` = not offered. Treated as paired with
  /// `wholesalePriceLkr`: the form rejects half-configured states.
  final int minOrderQuantity;
  final String keywords;
  final bool isActive;
  /// Per-product rating aggregate, mirrors the business rating fields.
  /// Bumped incrementally by `ProductReviewRepository` so the UI never
  /// has to scan the whole reviews collection.
  final double ratingAvg;
  final int ratingCount;
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
    required this.priceLkr,
    this.wholesalePriceLkr = 0.0,
    this.minOrderQuantity = 0,
    this.keywords = '',
    this.isActive = true,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
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
      priceLkr: (data['priceLkr'] ?? 0.0).toDouble(),
      wholesalePriceLkr:
          (data['wholesalePriceLkr'] ?? 0.0).toDouble(),
      minOrderQuantity:
          (data['minOrderQuantity'] as num?)?.toInt() ?? 0,
      keywords: data['keywords'] ?? '',
      isActive: data['isActive'] ?? true,
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
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
        'wholesalePriceLkr': wholesalePriceLkr,
        'minOrderQuantity': minOrderQuantity,
        'keywords': keywords,
        'isActive': isActive,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Product copyWith({
    String? title,
    String? shortTitle,
    String? description,
    String? category,
    String? image1Url,
    String? image2Url,
    String? image3Url,
    String? image4Url,
    double? priceLkr,
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
        priceLkr: priceLkr ?? this.priceLkr,
        wholesalePriceLkr: wholesalePriceLkr ?? this.wholesalePriceLkr,
        minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
        keywords: keywords ?? this.keywords,
        isActive: isActive ?? this.isActive,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        ratingCount: ratingCount ?? this.ratingCount,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
