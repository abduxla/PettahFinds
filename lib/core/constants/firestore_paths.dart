import 'app_constants.dart';

abstract class FirestorePaths {
  static String user(String uid) => '${AppConstants.usersCollection}/$uid';
  static String business(String id) =>
      '${AppConstants.businessesCollection}/$id';
  static String product(String id) => '${AppConstants.productsCollection}/$id';
  static String offer(String id) => '${AppConstants.offersCollection}/$id';
  static String review(String id) => '${AppConstants.reviewsCollection}/$id';
  static String favorite(String id) =>
      '${AppConstants.favoritesCollection}/$id';
  static String report(String id) => '${AppConstants.reportsCollection}/$id';
  static String notification(String id) =>
      '${AppConstants.notificationsCollection}/$id';

  // Storage paths
  static String businessLogo(String businessId) =>
      'businesses/$businessId/logo';
  static String businessBanner(String businessId) =>
      'businesses/$businessId/banner';
  // Scoped under businessId so Storage rules can authorize by business
  // ownership without an extra Firestore lookup per productId.
  static String productImage(String businessId, String productId, int index) =>
      'products/$businessId/$productId/image_$index';
  static String userPhoto(String uid) => 'users/$uid/photo';
}
