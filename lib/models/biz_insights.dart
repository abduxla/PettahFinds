import 'package:cloud_firestore/cloud_firestore.dart';

/// Nightly per-business market intelligence, written exclusively by the
/// `nightlyMarketAggregation` Cloud Function into `bizInsights/{businessId}`
/// (doc id == businessId; Firestore rules allow owner + admin reads only).
///
/// The app consumes a SUBSET of the doc — the fields behind the Vibranium
/// "Market position" card. The portal BI module reads the same doc for its
/// richer surfaces, so field names here must track functions/index.js.
class BizInsights {
  /// Rank across every business on the marketplace (1 = top).
  final int marketplacePosition;
  final int totalBusinesses;
  /// Display band, e.g. "Top 5%" / "Growing".
  final String percentileBand;
  /// Rank at the previous nightly run — null on a shop's first run.
  final int? prevMarketplacePosition;
  /// The shop's category and how its lifetime views compare against the
  /// category average, as a signed percentage (+38 = 38% above average).
  final String category;
  final int? viewsVsAvgPct;
  /// Search visibility over the trailing 7 days.
  final int searchImpressions7d;
  final int searchClicks7d;
  /// Colombo day-key of the run that produced this doc (YYYY-MM-DD).
  final String date;

  const BizInsights({
    required this.marketplacePosition,
    required this.totalBusinesses,
    required this.percentileBand,
    this.prevMarketplacePosition,
    this.category = '',
    this.viewsVsAvgPct,
    this.searchImpressions7d = 0,
    this.searchClicks7d = 0,
    this.date = '',
  });

  /// Positive = climbed since the previous night, negative = dropped.
  int? get movement => prevMarketplacePosition == null
      ? null
      : prevMarketplacePosition! - marketplacePosition;

  factory BizInsights.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bench = data['categoryBenchmark'] as Map<String, dynamic>?;
    final search = data['search7d'] as Map<String, dynamic>?;
    return BizInsights(
      marketplacePosition:
          (data['marketplacePosition'] as num?)?.toInt() ?? 0,
      totalBusinesses: (data['totalBusinesses'] as num?)?.toInt() ?? 0,
      percentileBand: data['percentileBand'] ?? '',
      prevMarketplacePosition:
          (data['prevMarketplacePosition'] as num?)?.toInt(),
      category: data['category'] ?? '',
      viewsVsAvgPct: (bench?['viewsVsAvgPct'] as num?)?.toInt(),
      searchImpressions7d: (search?['impressions'] as num?)?.toInt() ?? 0,
      searchClicks7d: (search?['clicks'] as num?)?.toInt() ?? 0,
      date: data['date'] ?? '',
    );
  }
}
