/// Membership levels for a business.
///
/// These are framed purely as **status / visibility levels** — never as
/// paid plans. The app never shows a price, an "upgrade" button, or a
/// comparison-to-buy. A level is assigned by an admin (see
/// `BusinessRepository.setTier`) based on verification, listing quality,
/// ratings, and customer engagement. Any off-app arrangement that drives
/// a level change lives entirely outside the app.
///
/// Mechanics: a business stores `tier` (the assigned level) plus an
/// optional `tierValidUntil` date. [Business.effectiveTier] downgrades a
/// paid level back to [BusinessTier.listed] once that date passes, so
/// perks lapse automatically with no background job required.
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

  /// Stable Firestore identifier — matches the enum name.
  String get id => name;

  /// Customer / seller-facing label. Status framing, never a price plan.
  String get label {
    switch (this) {
      case BusinessTier.listed:
        return 'Listed';
      case BusinessTier.spotlight:
        return 'Spotlight';
      case BusinessTier.prime:
        return 'Prime';
      case BusinessTier.elite:
        return 'Elite';
    }
  }

  /// Maximum number of **active** product listings this level allows.
  /// Elite is effectively unlimited (well above the 100-doc stream cap).
  int get listingCap {
    switch (this) {
      case BusinessTier.listed:
        return 5;
      case BusinessTier.spotlight:
        return 20;
      case BusinessTier.prime:
        return 50;
      case BusinessTier.elite:
        return 100000;
    }
  }

  /// Human label for the cap ("Unlimited" for Elite).
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

  /// Whether this level unlocks the seller analytics surface (Phase 3).
  bool get hasAnalytics =>
      this == BusinessTier.prime || this == BusinessTier.elite;

  /// Whether a visible status badge is shown on the shop / product cards.
  bool get hasBadge => this != BusinessTier.listed;

  /// Whether this is an assigned (non-floor) level that can expire.
  bool get isPaid => this != BusinessTier.listed;

  /// Perks shown on the seller's "Your level" screen. Visibility / status
  /// framing only — no money, no "upgrade" language.
  List<String> get perks {
    switch (this) {
      case BusinessTier.listed:
        return const [
          'Up to 5 active listings',
          'Appears in search & category browsing',
          'Customer chat & reviews',
        ];
      case BusinessTier.spotlight:
        return const [
          'Up to 20 active listings',
          'Priority placement in your category',
          'Spotlight badge on your shop',
        ];
      case BusinessTier.prime:
        return const [
          'Up to 50 active listings',
          'Featured on the home screen',
          'Prime badge on your shop',
          'Full performance analytics',
        ];
      case BusinessTier.elite:
        return const [
          'Unlimited active listings',
          'Top placement across the app',
          'Elite badge on your shop',
          'Full performance analytics',
          'Priority support',
        ];
    }
  }
}
