import '../models/business.dart';
import '../models/business_tier.dart';
import '../models/product.dart';

/// THE single marketplace ranking implementation, shared by every
/// customer discovery surface: home category sections, the See-all
/// products list, category pages, and the search default order (the
/// business directory uses [rankMarketplaceBusinesses] below).
///
/// Rules (in strict precedence order):
///  1. TIER BAND — premium (Vibranium + Platinum) before Gold, Gold
///     before Silver. Bands never interleave: tier priority always beats
///     popularity, so a viral Silver product still sits below premium.
///     Vibranium and Platinum share the premium band and compete
///     directly on the signals below.
///  2. VIEWS — within a band, lifetime views refine the order
///     ([Product.rankViews], denormalized onto product docs nightly by
///     the nightlyMarketAggregation Cloud Function — customer clients
///     cannot read the owner-only product_stats collection).
///  3. TIE-BREAK — the business that joined PetaFinds first wins; if
///     even that matches, the newer product wins as the final
///     deterministic key. Ordering is fully stable and predictable.
///
/// Tier signals stay INVISIBLE to customers (no badges, per the
/// trial-period decision) — the ordering applies quietly.
///
/// DO NOT roll surface-local ranking logic anywhere else: consistency
/// across surfaces is the point. If a surface needs a different order
/// it must be an explicit user choice (e.g. the search price sorts).

int marketplaceTierBand(BusinessTier tier) {
  switch (tier) {
    case BusinessTier.elite:
    case BusinessTier.prime:
      return 0;
    case BusinessTier.spotlight:
      return 1;
    case BusinessTier.listed:
      return 2;
  }
}

List<Product> rankMarketplaceProducts(
  List<Product> products,
  Business? Function(String businessId) businessOf,
) {
  // Pre-resolve per-product keys once — sort comparators run O(n log n)
  // times and the business lookup shouldn't be repeated inside them.
  final band = <String, int>{};
  final joined = <String, DateTime>{};
  for (final p in products) {
    final biz = businessOf(p.businessId);
    // Unknown business (join race) sinks to the bottom band rather than
    // being dropped — the verified-filter upstream already excludes
    // genuinely unverified sellers.
    band[p.id] = biz == null ? 2 : marketplaceTierBand(biz.effectiveTier);
    joined[p.id] = biz?.createdAt ?? DateTime(2100);
  }
  final out = [...products];
  out.sort((a, b) {
    final byBand = band[a.id]!.compareTo(band[b.id]!);
    if (byBand != 0) return byBand;
    final byViews = b.rankViews.compareTo(a.rankViews);
    if (byViews != 0) return byViews;
    final byJoined = joined[a.id]!.compareTo(joined[b.id]!);
    if (byJoined != 0) return byJoined;
    return b.createdAt.compareTo(a.createdAt);
  });
  return out;
}

/// Business-directory variant of the same rule: premium band first, then
/// Gold, then Silver. WITHIN a band the incoming order is preserved
/// (stable sort via index decoration — Dart's sort is not stable), so
/// the existing recency/relevance order keeps deciding among same-band
/// shops.
List<Business> rankMarketplaceBusinesses(List<Business> businesses) {
  final indexed = businesses.asMap().entries.toList();
  indexed.sort((a, b) {
    final byBand = marketplaceTierBand(a.value.effectiveTier)
        .compareTo(marketplaceTierBand(b.value.effectiveTier));
    if (byBand != 0) return byBand;
    return a.key.compareTo(b.key);
  });
  return [for (final e in indexed) e.value];
}
