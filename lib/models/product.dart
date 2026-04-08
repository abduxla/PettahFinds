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
  final double priceLkr;
  final String keywords;
  final bool isActive;
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
    this.keywords = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get imageUrls =>
      [image1Url, image2Url, image3Url, image4Url]
          .where((url) => url.isNotEmpty)
          .toList();

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
      keywords: data['keywords'] ?? '',
      isActive: data['isActive'] ?? true,
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
        'keywords': keywords,
        'isActive': isActive,
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
    String? keywords,
    bool? isActive,
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
        keywords: keywords ?? this.keywords,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
