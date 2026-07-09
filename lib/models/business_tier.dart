/// Membership levels for a business.
///
/// In-app these are presented as **status / visibility levels** — the app
/// itself never shows a price or an "upgrade to buy" flow. Commerce
/// (pricing, payments, invoices, upgrades) lives in the Business Portal at
/// petafinds.lk/portal, which shares these same stored ids. Keep the ids
/// (`listed/spotlight/prime/elite`) in lockstep with the portal's
/// `portal/src/config/tiers.ts` — the labels below are the commercial
/// names both surfaces display.
///
/// Mechanics: a business stores `tier` (the assigned level) plus an
/// optional `tierValidUntil` date. [Business.effectiveTier] downgrades a
/// paid level back to [BusinessTier.listed] once that date passes; the
/// backend's daily sweep is the authoritative enforcement (7-day grace).
///
/// This file is intentionally pure Dart (no Flutter imports) so it can be
/// used by models, repositories, and sort logic. Badge **rendering**
/// (icon + colour) lives in `widgets/tier_badge.dart`.
enum BusinessTier {
  listed,
  spotlight,
  prime,
  elite;

  /// Parse the Firestore string. Unknown / null → [listed] (the free floor).
  static BusinessTier fromId(String? id) {
    switch (id) {
      case 'spotlight':
        return BusinessTier.spotlight;
      case 'prime':
        return BusinessTier.prime;
      case 'elite':
        return BusinessTier.elite;
      case 'listed':
      default:
        return BusinessTier.listed;
    }
  }

  /// Stable Firestore identifier — matches the enum name. NEVER rename:
  /// the portal, Cloud Functions and stored business docs all key off it.
  String get id => name;

  /// Customer / seller-facing label — the commercial tier names shared
  /// with petafinds.lk (stored ids stay unchanged).
  String get label {
    switch (this) {
      case BusinessTier.listed:
        return 'Silver';
      case BusinessTier.spotlight:
        return 'Gold';
      case BusinessTier.prime:
        return 'Platinum';
      case BusinessTier.elite:
        return 'Vibranium';
    }
  }

  /// Maximum number of **active** product listings this level allows.
  /// Vibranium is effectively unlimited (well above the 100-doc stream cap).
  int get listingCap {
    switch (this) {
      case BusinessTier.listed:
        return 10;
      case BusinessTier.spotlight:
        return 50;
      case BusinessTier.prime:
        return 250;
      case BusinessTier.elite:
        return 100000;
    }
  }

  /// Human label for the cap ("Unlimited" for Vibranium).
  String get listingCapLabel =>
      this == BusinessTier.elite ? 'Unlimited' : '$listingCap';

  /// Sort boost for featured placement. Higher surfaces first; the floor
  /// level is 0 so it never reorders relative to recency.
  int get featuredWeight {
    switch (this) {
      case BusinessTier.listed:
        return 0;
      case BusinessTier.spotlight:
        return 1;
      case BusinessTier.prime:
        return 2;
      case BusinessTier.elite:
        return 3;
    }
  }

  /// Whether this level unlocks the live seller analytics surface.
  /// Gold gets a monthly report by email instead (backend scheduled job) —
  /// the live dashboard stays a Platinum/Vibranium differentiator.
  bool get hasAnalytics =>
      this == BusinessTier.prime || this == BusinessTier.elite;

  /// Whether a visible status badge is shown on the shop / product cards.
  bool get hasBadge => this != BusinessTier.listed;

  /// Whether this is an assigned (non-floor) level that can expire.
  bool get isPaid => this != BusinessTier.listed;

  /// Vibranium shops carry the "Recommended Supplier" tag on featured
  /// surfaces — the market-leader mark.
  bool get isRecommendedSupplier => this == BusinessTier.elite;

  /// Short, benefit-led headline for each level (shown on the seller's
  /// "Your level" screen). Matches the portal / website taglines.
  String get tagline {
    switch (this) {
      case BusinessTier.listed:
        return 'Start your digital presence';
      case BusinessTier.spotlight:
        return 'Get found by more customers';
      case BusinessTier.prime:
        return 'Grow faster & generate more leads';
      case BusinessTier.elite:
        return 'Maximum visibility & market leadership';
    }
  }

  /// Perks shown on the seller's "Your level" screen. Benefit-led and
  /// cumulative; aligned with the portal's plan cards. No prices in-app.
  List<String> get perks {
    switch (this) {
      case BusinessTier.listed:
        return const [
          'Up to 10 active listings',
          'Found in search & category browsing',
          'Your shop on the Pettah map',
          'Direct customer chat & reviews',
        ];
      case BusinessTier.spotlight:
        return const [
          'Up to 50 active listings',
          'Higher ranking above standard shops',
          'Gold badge — a trusted, active shop',
          'Monthly business report with product insights',
        ];
      case BusinessTier.prime:
        return const [
          'Up to 250 active listings',
          'Featured on the home screen where shoppers land',
          'Platinum badge buyers look for',
          'Full live analytics — views, chats & top products',
        ];
      case BusinessTier.elite:
        return const [
          'Unlimited active listings',
          'Highest placement across the whole app',
          'Recommended Supplier tag on featured surfaces',
          'Vibranium badge — the highest mark of trust',
          'Full live analytics + priority support',
        ];
    }
  }
}
