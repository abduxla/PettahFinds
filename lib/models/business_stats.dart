import 'package:cloud_firestore/cloud_firestore.dart';

/// Rolling engagement counters for a business, stored at
/// `business_stats/{businessId}`. Written best-effort by [AnalyticsRepository]
/// via `FieldValue.increment`, read by the seller analytics screen (gated to
/// levels with [BusinessTier.hasAnalytics]).
///
/// These are vanity / performance metrics only — never used for placement
/// (placement is tier-based and admin-controlled), so the relaxed write
/// rule is low-stakes.
class BusinessStats {
  final int profileViews;
  final int productViews;
  final int chatsStarted;
  final int saves;

  const BusinessStats({
    this.profileViews = 0,
    this.productViews = 0,
    this.chatsStarted = 0,
    this.saves = 0,
  });

  static const empty = BusinessStats();

  /// Total customer touch-points — a single headline number for the
  /// dashboard hero.
  int get totalEngagements =>
      profileViews + productViews + chatsStarted + saves;

  factory BusinessStats.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    int read(String k) => (data[k] as num?)?.toInt() ?? 0;
    return BusinessStats(
      profileViews: read('profileViews'),
      productViews: read('productViews'),
      chatsStarted: read('chatsStarted'),
      saves: read('saves'),
    );
  }
}
