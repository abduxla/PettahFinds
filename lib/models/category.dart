import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String iconName;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.iconName,
    this.isActive = true,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      iconName: data['iconName'] ?? 'category',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconName': iconName,
        'isActive': isActive,
      };
}
