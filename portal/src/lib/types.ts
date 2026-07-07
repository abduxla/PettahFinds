import type {
  DocumentData,
  DocumentSnapshot,
  Timestamp,
} from "firebase/firestore";
import { tierFromId, type TierId } from "@/config/tiers";

/**
 * TypeScript mirrors of the Flutter models. Field names MUST match the
 * Dart `toMap()` serializers exactly (lib/models/*.dart) — the portal and
 * the mobile app read and write the same documents.
 */

export type UserRole = "user" | "business" | "admin";

export interface AppUser {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  businessId: string | null;
  onboardingCompleted: boolean;
  phoneNumber: string | null;
  photoUrl: string | null;
  /** Set by provisionPortalAccess; forces a password change on first login. */
  mustChangePassword: boolean;
  createdAt: Date | null;
}

export function appUserFromDoc(
  snap: DocumentSnapshot<DocumentData>,
): AppUser | null {
  if (!snap.exists()) return null;
  const d = snap.data() ?? {};
  return {
    uid: snap.id,
    email: (d.email as string) ?? "",
    displayName: (d.displayName as string) ?? "",
    role: (["user", "business", "admin"] as const).includes(d.role)
      ? (d.role as UserRole)
      : "user",
    businessId: (d.businessId as string) || null,
    onboardingCompleted: d.onboardingCompleted === true,
    phoneNumber: (d.phoneNumber as string) || null,
    photoUrl: (d.photoUrl as string) || null,
    mustChangePassword: d.mustChangePassword === true,
    createdAt: toDate(d.createdAt),
  };
}

export interface Business {
  id: string;
  businessName: string;
  ownerUid: string;
  ownerName: string;
  ownerPhone: string;
  location: string;
  description: string;
  phone: string;
  email: string;
  whatsappNumber: string;
  category: string;
  logoUrl: string;
  bannerUrl: string;
  isVerified: boolean;
  /** Portal-era field; absent on legacy docs (treated as not suspended). */
  suspended: boolean;
  ratingAvg: number;
  ratingCount: number;
  tier: TierId;
  tierValidUntil: Date | null;
  createdAt: Date | null;
  createdByAdminUid: string | null;
}

export function businessFromDoc(
  snap: DocumentSnapshot<DocumentData>,
): Business | null {
  if (!snap.exists()) return null;
  const d = snap.data() ?? {};
  return {
    id: snap.id,
    businessName: (d.businessName as string) ?? "",
    ownerUid: (d.ownerUid as string) ?? "",
    ownerName: (d.ownerName as string) ?? "",
    ownerPhone: (d.ownerPhone as string) ?? "",
    location: (d.location as string) ?? "",
    description: (d.description as string) ?? "",
    phone: (d.phone as string) ?? "",
    email: (d.email as string) ?? "",
    whatsappNumber: (d.whatsappNumber as string) ?? "",
    category: (d.category as string) ?? "",
    logoUrl: (d.logoUrl as string) ?? "",
    bannerUrl: (d.bannerUrl as string) ?? "",
    isVerified: d.isVerified === true,
    suspended: d.suspended === true,
    ratingAvg: typeof d.ratingAvg === "number" ? d.ratingAvg : 0,
    ratingCount: typeof d.ratingCount === "number" ? d.ratingCount : 0,
    tier: tierFromId(d.tier as string | undefined),
    tierValidUntil: toDate(d.tierValidUntil),
    createdAt: toDate(d.createdAt),
    createdByAdminUid: (d.createdByAdminUid as string) || null,
  };
}

/** Firestore Timestamp | Date | null → Date | null */
export function toDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function")
    return (v as Timestamp).toDate();
  return null;
}
