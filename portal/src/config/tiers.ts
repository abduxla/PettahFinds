/**
 * Membership tier catalogue.
 *
 * CRITICAL: the stored Firestore IDs (`listed`/`spotlight`/`prime`/`elite`)
 * are shared with the live mobile app (lib/models/business_tier.dart) and
 * MUST NOT change — badges, listing caps and featured placement in the
 * shipped App Store build key off these IDs. The portal maps them to the
 * commercial names (Silver/Gold/Platinum/Vibranium) for display only.
 *
 * Pricing here is the compiled-in default; the live source of truth is the
 * `portalConfig/tiers` Firestore doc (admin-editable) which overrides these
 * values when present — see useTierCatalogue().
 */

export const TIER_IDS = ["listed", "spotlight", "prime", "elite"] as const;
export type TierId = (typeof TIER_IDS)[number];

export interface TierPlan {
  /** Stored Firestore ID — shared with the mobile app. Never rename. */
  id: TierId;
  /** Commercial display name used across the portal. */
  name: string;
  /** LKR per month; 0 = free. */
  priceLkr: number;
  tagline: string;
  /** Product listing cap; null = unlimited. */
  productCap: number | null;
  features: string[];
  /** Marketing ribbon shown on the comparison table. */
  ribbon?: "MOST POPULAR" | "MARKET LEADER";
  /** CSS color token for badges/accents. */
  colorVar: string;
}

export const TIER_PLANS: Record<TierId, TierPlan> = {
  listed: {
    id: "listed",
    name: "Silver",
    priceLkr: 0,
    tagline: "Start Your Digital Presence",
    productCap: 10,
    features: [
      "Up to 10 Products",
      "Business Profile",
      "Appear in Search",
      "Appear on Map",
      "Receive Inquiries",
    ],
    colorVar: "var(--color-tier-silver)",
  },
  spotlight: {
    id: "spotlight",
    name: "Gold",
    priceLkr: 5490,
    tagline: "Get Found By More Customers",
    productCap: 50,
    features: [
      "Up to 50 Products",
      "Higher Search Ranking",
      "Featured Business Badge",
      "Product Insights",
      "Monthly Business Report",
    ],
    colorVar: "var(--color-tier-gold)",
  },
  prime: {
    id: "prime",
    name: "Platinum",
    priceLkr: 9999,
    tagline: "Grow Faster & Generate More Leads",
    productCap: 250,
    features: [
      "Up to 250 Products",
      "Premium Search Placement",
      "Business Analytics",
      "Priority Exposure",
      "Verified Business Badge",
    ],
    ribbon: "MOST POPULAR",
    colorVar: "var(--color-tier-platinum)",
  },
  elite: {
    id: "elite",
    name: "Vibranium",
    priceLkr: 24999,
    tagline: "Maximum Visibility & Market Leadership",
    productCap: null,
    features: [
      "Unlimited Products",
      "Highest Search Priority",
      "Homepage Promotion Eligibility",
      "Recommended Supplier Eligibility",
      "Advanced Business Insights",
    ],
    ribbon: "MARKET LEADER",
    colorVar: "var(--color-tier-vibranium)",
  },
};

export const TIER_ORDER: TierId[] = ["listed", "spotlight", "prime", "elite"];

/** Parse a stored tier id; unknown/absent values fall back to the free tier
 *  (same behavior as BusinessTier.fromId in the mobile app). */
export function tierFromId(id?: string | null): TierId {
  return (TIER_IDS as readonly string[]).includes(id ?? "")
    ? (id as TierId)
    : "listed";
}

/**
 * The tier a business is currently entitled to: a paid tier silently
 * downgrades to the free tier once `tierValidUntil` has passed (mirrors
 * Business.effectiveTier in the mobile app so both clients always agree).
 */
export function effectiveTier(
  tier: TierId,
  tierValidUntil: Date | null,
): TierId {
  if (tier === "listed") return "listed";
  if (!tierValidUntil || tierValidUntil.getTime() < Date.now())
    return "listed";
  return tier;
}

export function planOf(id?: string | null): TierPlan {
  return TIER_PLANS[tierFromId(id)];
}
