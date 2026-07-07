"use client";

import { useMemo, useState, type FormEvent } from "react";
import {
  collection,
  doc,
  orderBy,
  query,
  where,
} from "firebase/firestore";
import {
  getDownloadURL,
  ref as storageRef,
  uploadBytesResumable,
} from "firebase/storage";
import { FirebaseError } from "firebase/app";
import { db, storage } from "@/lib/firebase";
import { useBusiness } from "@/lib/business-context";
import { useDoc, useQuerySub } from "@/lib/firestore-hooks";
import {
  PAYMENT_METHOD_LABELS,
  paymentFromDoc,
  paymentsConfigFromDoc,
  submitPayment,
  type Payment,
  type PaymentMethod,
} from "@/lib/payments";
import { TIER_PLANS, type TierId } from "@/config/tiers";
import { formatDate, formatLkr } from "@/lib/format";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Spinner } from "@/components/ui/spinner";
import { EmptyState } from "@/components/ui/empty-state";
import { PaymentTimeline } from "@/components/payment-timeline";
import { cn } from "@/lib/cn";

const PAID_TIERS: TierId[] = ["spotlight", "prime", "elite"];
const MONTH_OPTIONS = [1, 3, 6, 12];
const ACCEPTED_FILES = ".pdf,.png,.jpg,.jpeg,.heic";

export default function PaymentsPage() {
  const { business } = useBusiness();
  if (!business) return null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Payments
        </h1>
        <p className="mt-0.5 text-sm text-ink-500">
          Pay for your membership by bank transfer and upload the receipt —
          the PetaFinds team verifies it, usually within one business day.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-5">
        <div className="space-y-6 lg:col-span-2">
          <PaymentMethodsCard />
        </div>
        <div className="lg:col-span-3">
          <SubmitPaymentCard businessId={business.id} />
        </div>
      </div>

      <PaymentHistory businessId={business.id} />
    </div>
  );
}

/** Bank / deposit details from portalConfig/payments (admin-managed). */
function PaymentMethodsCard() {
  const { data: config, loading } = useDoc(
    doc(db, "portalConfig", "payments"),
    paymentsConfigFromDoc,
  );

  return (
    <Card>
      <CardHeader
        title="How to pay"
        subtitle="Deposit or transfer to this account"
      />
      <CardBody>
        {loading ? (
          <div className="flex justify-center py-6">
            <Spinner />
          </div>
        ) : !config || !config.accountNumber ? (
          <EmptyState
            title="Payment details coming soon"
            message="Bank details haven't been published yet — contact support to arrange payment."
          />
        ) : (
          <div className="space-y-2 text-sm">
            <Row label="Bank" value={config.bankName} />
            <Row label="Account name" value={config.accountName} />
            <Row
              label="Account number"
              value={<span className="font-mono">{config.accountNumber}</span>}
            />
            <Row label="Branch" value={config.branch} />
            {config.instructions && (
              <p className="rounded-(--radius-input) bg-orange-soft px-3.5 py-2.5 text-[13px] leading-relaxed text-ink-700">
                {config.instructions}
              </p>
            )}
          </div>
        )}
      </CardBody>
    </Card>
  );
}

/** Tier + months + evidence → Storage upload → submitPayment callable. */
function SubmitPaymentCard({ businessId }: { businessId: string }) {
  const [tier, setTier] = useState<TierId>("spotlight");
  const [months, setMonths] = useState(1);
  const [method, setMethod] = useState<PaymentMethod>("bank_transfer");
  const [reference, setReference] = useState("");
  const [paidOn, setPaidOn] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [notes, setNotes] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const amount = TIER_PLANS[tier].priceLkr * months;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setMsg(null);
    if (!file) {
      setMsg({ ok: false, text: "Attach your payment receipt first." });
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setMsg({ ok: false, text: "Receipt must be under 10 MB." });
      return;
    }
    if (reference.trim().length < 3) {
      setMsg({
        ok: false,
        text: "Enter the reference number from your deposit slip / transfer.",
      });
      return;
    }

    setBusy(true);
    try {
      // 1. Upload the evidence under the business's own receipts prefix.
      const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-60);
      const path = `receipts/${businessId}/${Date.now()}_${safeName}`;
      const task = uploadBytesResumable(storageRef(storage, path), file, {
        contentType: file.type || "application/octet-stream",
      });
      await new Promise<void>((resolve, reject) => {
        task.on(
          "state_changed",
          (s) => setProgress((s.bytesTransferred / s.totalBytes) * 100),
          reject,
          () => resolve(),
        );
      });
      setProgress(null);

      // 2. Register the payment — the server computes the amount and
      //    rejects duplicates (same reference + amount + date).
      const res = await submitPayment({
        tierRequested: tier,
        months,
        method,
        referenceNumber: reference.trim(),
        paidOn,
        receiptPath: path,
        notes: notes.trim() || undefined,
      });
      setMsg({
        ok: true,
        text: `Payment of ${formatLkr(res.amountLkr)} submitted — you'll be notified once it's verified.`,
      });
      setReference("");
      setNotes("");
      setFile(null);
    } catch (err) {
      const text =
        err instanceof FirebaseError && err.message
          ? err.message
          : "Submission failed — check your connection and try again.";
      setMsg({ ok: false, text });
    } finally {
      setProgress(null);
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader
        title="Submit a payment"
        subtitle="Upload your receipt for verification"
      />
      <CardBody>
        <form onSubmit={onSubmit} className="space-y-4" noValidate>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="flex flex-col gap-1.5 text-[13px] font-semibold text-ink-700">
              Plan
              <select
                value={tier}
                onChange={(e) => setTier(e.target.value as TierId)}
                className="h-11 cursor-pointer rounded-(--radius-input) border border-line bg-surface px-3 text-sm font-normal text-ink-900 focus:border-teal focus:outline-none"
              >
                {PAID_TIERS.map((id) => (
                  <option key={id} value={id}>
                    {TIER_PLANS[id].name} — {formatLkr(TIER_PLANS[id].priceLkr)}
                    /mo
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1.5 text-[13px] font-semibold text-ink-700">
              Duration
              <select
                value={months}
                onChange={(e) => setMonths(Number(e.target.value))}
                className="h-11 cursor-pointer rounded-(--radius-input) border border-line bg-surface px-3 text-sm font-normal text-ink-900 focus:border-teal focus:outline-none"
              >
                {MONTH_OPTIONS.map((m) => (
                  <option key={m} value={m}>
                    {m} month{m > 1 ? "s" : ""}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="flex items-center justify-between rounded-(--radius-input) bg-teal-light px-4 py-3">
            <span className="text-[13px] font-semibold text-teal-dark">
              Amount payable
            </span>
            <span className="font-display text-lg font-black text-teal-dark">
              {formatLkr(amount)}
            </span>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="flex flex-col gap-1.5 text-[13px] font-semibold text-ink-700">
              Payment method
              <select
                value={method}
                onChange={(e) => setMethod(e.target.value as PaymentMethod)}
                className="h-11 cursor-pointer rounded-(--radius-input) border border-line bg-surface px-3 text-sm font-normal text-ink-900 focus:border-teal focus:outline-none"
              >
                {Object.entries(PAYMENT_METHOD_LABELS).map(([id, label]) => (
                  <option key={id} value={id}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1.5 text-[13px] font-semibold text-ink-700">
              Payment date
              <input
                type="date"
                value={paidOn}
                max={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setPaidOn(e.target.value)}
                className="h-11 rounded-(--radius-input) border border-line bg-surface px-3 text-sm font-normal text-ink-900 focus:border-teal focus:outline-none"
              />
            </label>
          </div>

          <Input
            label="Reference number"
            placeholder="Slip / transaction reference"
            value={reference}
            onChange={(e) => setReference(e.target.value)}
            hint="From your deposit slip or banking app — used to verify the payment."
            required
          />

          <div className="flex flex-col gap-1.5">
            <span className="text-[13px] font-semibold text-ink-700">
              Receipt (PDF, PNG, JPG or HEIC — max 10 MB)
            </span>
            <label
              className={cn(
                "flex cursor-pointer items-center justify-center gap-2 rounded-(--radius-input) border border-dashed px-4 py-5 text-[13px] font-semibold transition-colors",
                file
                  ? "border-teal bg-teal-light text-teal-dark"
                  : "border-line text-ink-500 hover:border-teal hover:text-teal",
              )}
            >
              <input
                type="file"
                accept={ACCEPTED_FILES}
                className="hidden"
                onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              />
              {file ? `📎 ${file.name}` : "Click to attach your receipt"}
            </label>
            {progress !== null && (
              <div className="h-1.5 overflow-hidden rounded-full bg-bg-section">
                <div
                  className="h-full rounded-full bg-teal transition-all duration-200"
                  style={{ width: `${progress}%` }}
                />
              </div>
            )}
          </div>

          <Input
            label="Notes (optional)"
            placeholder="Anything the verification team should know"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />

          {msg && (
            <div
              role="status"
              className={cn(
                "rounded-(--radius-input) border px-4 py-3 text-[13px] font-semibold",
                msg.ok
                  ? "border-success/25 bg-success-soft text-success"
                  : "border-danger/25 bg-danger-soft text-danger",
              )}
            >
              {msg.text}
            </div>
          )}

          <Button type="submit" size="lg" loading={busy} className="w-full">
            Submit for verification
          </Button>
        </form>
      </CardBody>
    </Card>
  );
}

/** Live history with expandable rows (timeline + receipt link). */
function PaymentHistory({ businessId }: { businessId: string }) {
  const q = useMemo(
    () =>
      query(
        collection(db, "payments"),
        where("businessId", "==", businessId),
        orderBy("createdAt", "desc"),
      ),
    [businessId],
  );
  const { data: payments, loading } = useQuerySub(
    q,
    paymentFromDoc,
    `payments-${businessId}`,
  );
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <Card>
      <CardHeader
        title="Payment history"
        subtitle={`${payments.length} submission${payments.length === 1 ? "" : "s"}`}
      />
      <CardBody className="px-0 pb-2 pt-3">
        {loading ? (
          <div className="flex justify-center py-10">
            <Spinner />
          </div>
        ) : payments.length === 0 ? (
          <EmptyState
            title="No payments yet"
            message="Your submitted payments and their verification status will appear here."
          />
        ) : (
          <ul className="divide-y divide-line/70">
            {payments.map((p) => (
              <PaymentRow
                key={p.id}
                payment={p}
                open={openId === p.id}
                onToggle={() => setOpenId(openId === p.id ? null : p.id)}
              />
            ))}
          </ul>
        )}
      </CardBody>
    </Card>
  );
}

function statusBadge(p: Payment) {
  switch (p.status) {
    case "approved":
      return <Badge tone="success">Approved</Badge>;
    case "rejected":
      return <Badge tone="danger">Rejected</Badge>;
    case "resubmission_requested":
      return <Badge tone="orange">Resubmit</Badge>;
    default:
      return <Badge tone="orange">Pending Verification</Badge>;
  }
}

function PaymentRow({
  payment: p,
  open,
  onToggle,
}: {
  payment: Payment;
  open: boolean;
  onToggle: () => void;
}) {
  const [receiptUrl, setReceiptUrl] = useState<string | null>(null);

  async function openReceipt() {
    try {
      const url =
        receiptUrl ??
        (await getDownloadURL(storageRef(storage, p.receiptPath)));
      setReceiptUrl(url);
      window.open(url, "_blank", "noopener");
    } catch {
      /* receipt unavailable */
    }
  }

  return (
    <li>
      <button
        onClick={onToggle}
        className="flex w-full cursor-pointer items-center justify-between gap-3 px-6 py-3.5 text-left transition-colors hover:bg-bg-section/60"
      >
        <div className="min-w-0">
          <p className="text-sm font-bold text-ink-900">
            {formatLkr(p.amountLkr)}{" "}
            <span className="font-normal text-ink-500">
              · {TIER_PLANS[p.tierRequested].name} · {p.months} mo ·{" "}
              {PAYMENT_METHOD_LABELS[p.method]}
            </span>
          </p>
          <p className="truncate text-xs text-ink-500">
            Ref {p.referenceNumber} · paid {formatDate(p.paidOn)} · submitted{" "}
            {formatDate(p.createdAt)}
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          {statusBadge(p)}
          <span
            className={cn(
              "text-ink-300 transition-transform",
              open && "rotate-180",
            )}
          >
            ▾
          </span>
        </div>
      </button>
      {open && (
        <div className="space-y-3 bg-bg-section/50 px-6 py-4">
          <PaymentTimeline status={p.status} />
          {p.reviewNote && (
            <p className="text-[13px] text-ink-700">
              <span className="font-bold">Reviewer note:</span> {p.reviewNote}
            </p>
          )}
          <Button variant="secondary" size="sm" onClick={() => void openReceipt()}>
            View receipt
          </Button>
        </div>
      )}
    </li>
  );
}

function Row({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-line/60 pb-2 last:border-0 last:pb-0">
      <span className="text-ink-500">{label}</span>
      <span className="text-right font-semibold text-ink-900">{value}</span>
    </div>
  );
}
