abstract class AppConstants {
  static const String appName = 'PetaFinds';
  static const String appTagline = 'Discover local businesses & deals';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String businessesCollection = 'businesses';
  static const String categoriesCollection = 'categories';
  static const String productsCollection = 'products';
  static const String offersCollection = 'offers';
  static const String reviewsCollection = 'reviews';
  static const String favoritesCollection = 'favorites';
  static const String reportsCollection = 'reports';
  static const String notificationsCollection = 'notifications';

  // Roles
  static const String roleUser = 'user';
  static const String roleBusiness = 'business';
  static const String roleAdmin = 'admin';

  // Stock statuses
  static const String stockInStock = 'in_stock';
  static const String stockLow = 'low';
  static const String stockOut = 'out';

  // Membership tiers
  static const String tierFree = 'free';
  static const String tierBasic = 'basic';
  static const String tierPremium = 'premium';

  // Pagination
  static const int defaultPageSize = 20;

  // Image constraints
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const double maxImageWidth = 1200;
}
