import type {
  DocumentData,
  DocumentSnapshot,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import { toDate } from "@/lib/types";
import { tierFromId, type TierId } from "@/config/tiers";

/** Mirrors the payments doc shape written by submitPayment/reviewPayment
 *  (functions/index.js). Client-side this is READ-ONLY — rules deny all
 *  client writes to /payments. */

export type PaymentStatus =
  | "pending_verification"
  | "approved"
  | "rejected"
  | "resubmission_requested";

export type PaymentMethod =
  | "bank_transfer"
  | "cash_deposit"
  | "online_transfer"
  | "qr";

export const PAYMENT_METHOD_LABELS: Record<PaymentMethod, string> = {
  bank_transfer: "Bank Transfer",
  cash_deposit: "Cash Deposit",
  online_transfer: "Online Transfer",
  qr: "QR Payment",
};

export interface Payment {
  id: string;
  businessId: string;
  submittedByUid: string;
  tierRequested: TierId;
  months: number;
  amountLkr: number;
  method: PaymentMethod;
  referenceNumber: string;
  paidOn: Date | null;
  receiptPath: string;
  notes: string;
  status: PaymentStatus;
  createdAt: Date | null;
  reviewedAt: Date | null;
  reviewNote: string;
}

export function paymentFromDoc(
  snap: DocumentSnapshot<DocumentData>,
): Payment | null {
  if (!snap.exists()) return null;
  const d = snap.data() ?? {};
  const status = ([
    "pending_verification",
    "approved",
    "rejected",
    "resubmission_requested",
  ] as const).includes(d.status)
    ? (d.status as PaymentStatus)
    : "pending_verification";
  const method = (
    ["bank_transfer", "cash_deposit", "online_transfer", "qr"] as const
  ).includes(d.method)
    ? (d.method as PaymentMethod)
    : "bank_transfer";
  return {
    id: snap.id,
    businessId: (d.businessId as string) ?? "",
    submittedByUid: (d.submittedByUid as string) ?? "",
    tierRequested: tierFromId(d.tierRequested as string),
    months: typeof d.months === "number" ? d.months : 1,
    amountLkr: typeof d.amountLkr === "number" ? d.amountLkr : 0,
    method,
    referenceNumber: (d.referenceNumber as string) ?? "",
    paidOn: toDate(d.paidOn),
    receiptPath: (d.receiptPath as string) ?? "",
    notes: (d.notes as string) ?? "",
    status,
    createdAt: toDate(d.createdAt),
    reviewedAt: toDate(d.reviewedAt),
    reviewNote: (d.reviewNote as string) ?? "",
  };
}

/** Bank/QR details rendered on the business payments page. Stored in
 *  portalConfig/payments (admin-editable — never hardcoded). */
export interface PaymentsConfig {
  bankName: string;
  accountName: string;
  accountNumber: string;
  branch: string;
  instructions: string;
}

export function paymentsConfigFromDoc(
  snap: DocumentSnapshot<DocumentData>,
): PaymentsConfig | null {
  if (!snap.exists()) return null;
  const d = snap.data() ?? {};
  return {
    bankName: (d.bankName as string) ?? "",
    accountName: (d.accountName as string) ?? "",
    accountNumber: (d.accountNumber as string) ?? "",
    branch: (d.branch as string) ?? "",
    instructions: (d.instructions as string) ?? "",
  };
}

// ---- callable wrappers ----

export interface SubmitPaymentInput {
  tierRequested: TierId;
  months: number;
  method: PaymentMethod;
  referenceNumber: string;
  /** YYYY-MM-DD */
  paidOn: string;
  receiptPath: string;
  notes?: string;
}

export async function submitPayment(
  input: SubmitPaymentInput,
): Promise<{ ok: boolean; paymentId: string; amountLkr: number }> {
  const fn = httpsCallable<
    SubmitPaymentInput,
    { ok: boolean; paymentId: string; amountLkr: number }
  >(functions, "submitPayment");
  return (await fn(input)).data;
}

export async function reviewPayment(
  paymentId: string,
  decision: "approve" | "reject" | "resubmit",
  note?: string,
): Promise<{ ok: boolean; status: string }> {
  const fn = httpsCallable<
    { paymentId: string; decision: string; note?: string },
    { ok: boolean; status: string }
  >(functions, "reviewPayment");
  return (await fn({ paymentId, decision, note })).data;
}
