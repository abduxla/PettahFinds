"use client";

import { useMemo, useState, type FormEvent } from "react";
import {
  collection,
  doc,
  orderBy,
  query,
  setDoc,
} from "firebase/firestore";
import { getDownloadURL, ref as storageRef } from "firebase/storage";
import { db, storage } from "@/lib/firebase";
import { useDoc, useQuerySub } from "@/lib/firestore-hooks";
import { useAllBusinesses } from "@/lib/admin-data";
import {
  PAYMENT_METHOD_LABELS,
  paymentFromDoc,
  paymentsConfigFromDoc,
  reviewPayment,
  type Payment,
} from "@/lib/payments";
import { callableError } from "@/lib/callables";
import { TIER_PLANS } from "@/config/tiers";
import { formatDate, formatLkr } from "@/lib/format";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Spinner } from "@/components/ui/spinner";
import { EmptyState } from "@/components/ui/empty-state";
import { cn } from "@/lib/cn";

type Tab = "pending" | "approved" | "rejected" | "all";
const TABS: { id: Tab; label: string }[] = [
  { id: "pending", label: "Pending" },
  { id: "approved", label: "Approved" },
  { id: "rejected", label: "Rejected / Resubmit" },
  { id: "all", label: "All" },
];

export default function AdminPaymentsPage() {
  const q = useMemo(
    () => query(collection(db, "payments"), orderBy("createdAt", "desc")),
    [],
  );
  const { data: payments, loading } = useQuerySub(
    q,
    paymentFromDoc,
    "admin-payments",
  );
  const { data: businesses } = useAllBusinesses();
  const bizName = useMemo(() => {
    const map = new Map<string, string>();
    businesses.forEach((b) => map.set(b.id, b.businessName));
    return map;
  }, [businesses]);

  const [tab, setTab] = useState<Tab>("pending");
  const [search, setSearch] = useState("");

  const filtered = useMemo(() => {
    const ql = search.trim().toLowerCase();
    return payments.filter((p) => {
      if (tab === "pending" && p.status !== "pending_verification")
        return false;
      if (tab === "approved" && p.status !== "approved") return false;
      if (
        tab === "rejected" &&
        p.status !== "rejected" &&
        p.status !== "resubmission_requested"
      )
        return false;
      if (ql) {
        const name = (bizName.get(p.businessId) ?? "").toLowerCase();
        if (
          !p.referenceNumber.toLowerCase().includes(ql) &&
          !name.includes(ql) &&
          !p.businessId.toLowerCase().includes(ql)
        )
          return false;
      }
      return true;
    });
  }, [payments, tab, search, bizName]);

  const pendingCount = payments.filter(
    (p) => p.status === "pending_verification",
  ).length;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Payments
        </h1>
        <p className="mt-0.5 text-sm text-ink-500">
          {pendingCount} awaiting verification · {payments.length} total
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-(--radius-input) border border-line bg-surface p-1">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={cn(
                "cursor-pointer rounded-lg px-3.5 py-1.5 text-[13px] font-semibold transition-colors",
                tab === t.id
                  ? "bg-teal-light text-teal-dark"
                  : "text-ink-500 hover:text-ink-700",
              )}
            >
              {t.label}
              {t.id === "pending" && pendingCount > 0 && (
                <span className="ml-1.5 rounded-full bg-orange px-1.5 text-[10px] font-black text-white">
                  {pendingCount}
                </span>
              )}
            </button>
          ))}
        </div>
        <input
          type="search"
          placeholder="Search reference, business…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="h-10 min-w-56 flex-1 rounded-(--radius-input) border border-line bg-surface px-3.5 text-[13px] text-ink-900 placeholder:text-ink-300 focus:border-teal focus:outline-none focus:ring-2 focus:ring-teal/25"
        />
      </div>

      <Card className="overflow-hidden">
        {loading ? (
          <div className="flex justify-center py-16">
            <Spinner className="size-7" />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            title={
              tab === "pending" ? "Verification queue is clear" : "No payments"
            }
            message="Merchant payment submissions will appear here."
          />
        ) : (
          <ul className="divide-y divide-line/70">
            {filtered.map((p) => (
              <AdminPaymentRow
                key={p.id}
                payment={p}
                businessName={bizName.get(p.businessId) ?? p.businessId}
              />
            ))}
          </ul>
        )}
      </Card>

      <PaymentSettingsCard />
    </div>
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
      return <Badge tone="orange">Pending</Badge>;
  }
}

function AdminPaymentRow({
  payment: p,
  businessName,
}: {
  payment: Payment;
  businessName: string;
}) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [receiptUrl, setReceiptUrl] = useState<string | null>(null);

  async function loadReceipt() {
    try {
      const url = await getDownloadURL(storageRef(storage, p.receiptPath));
      setReceiptUrl(url);
    } catch {
      setMsg({ ok: false, text: "Receipt file could not be loaded." });
    }
  }

  async function decide(decision: "approve" | "reject" | "resubmit") {
    if (
      (decision === "reject" || decision === "resubmit") &&
      note.trim().length < 3
    ) {
      setMsg({
        ok: false,
        text: "Add a short note for the merchant explaining why.",
      });
      return;
    }
    setBusy(decision);
    setMsg(null);
    try {
      const res = await reviewPayment(p.id, decision, note.trim() || undefined);
      setMsg({ ok: true, text: `Payment ${res.status.replace(/_/g, " ")}.` });
    } catch (err) {
      setMsg({ ok: false, text: callableError(err) });
    } finally {
      setBusy(null);
    }
  }

  const isPdf = p.receiptPath.toLowerCase().endsWith(".pdf");

  return (
    <li>
      <button
        onClick={() => {
          setOpen(!open);
          if (!open && !receiptUrl) void loadReceipt();
        }}
        className="flex w-full cursor-pointer items-center justify-between gap-3 px-6 py-3.5 text-left transition-colors hover:bg-bg-section/60"
      >
        <div className="min-w-0">
          <p className="truncate text-sm font-bold text-ink-900">
            {businessName}
            <span className="font-normal text-ink-500">
              {" "}
              · {formatLkr(p.amountLkr)} · {TIER_PLANS[p.tierRequested].name} ·{" "}
              {p.months} mo
            </span>
          </p>
          <p className="truncate text-xs text-ink-500">
            {PAYMENT_METHOD_LABELS[p.method]} · Ref {p.referenceNumber} · paid{" "}
            {formatDate(p.paidOn)} · submitted {formatDate(p.createdAt)}
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
        <div className="grid gap-4 bg-bg-section/50 px-6 py-4 lg:grid-cols-2">
          {/* Receipt preview */}
          <div className="space-y-2">
            <p className="text-xs font-bold uppercase tracking-wide text-ink-500">
              Receipt
            </p>
            {receiptUrl ? (
              <>
                {isPdf ? (
                  <iframe
                    src={receiptUrl}
                    title="Receipt PDF"
                    className="h-72 w-full rounded-(--radius-input) border border-line bg-white"
                  />
                ) : (
                  // eslint-disable-next-line @next/next/no-img-element -- static export, signed Storage URL
                  <img
                    src={receiptUrl}
                    alt="Payment receipt"
                    className="max-h-72 w-full rounded-(--radius-input) border border-line bg-white object-contain"
                  />
                )}
                <a
                  href={receiptUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-block text-[13px] font-semibold text-teal hover:text-teal-dark"
                >
                  Open full size / zoom ↗
                </a>
              </>
            ) : (
              <div className="flex h-40 items-center justify-center rounded-(--radius-input) border border-line bg-surface">
                <Spinner />
              </div>
            )}
            {p.notes && (
              <p className="text-[13px] text-ink-700">
                <span className="font-bold">Merchant note:</span> {p.notes}
              </p>
            )}
          </div>

          {/* Review actions */}
          <div className="space-y-3">
            <p className="text-xs font-bold uppercase tracking-wide text-ink-500">
              Review
            </p>
            {p.status === "pending_verification" ? (
              <>
                <Input
                  label="Note to merchant (required for reject/resubmit)"
                  placeholder="e.g. Reference number doesn't match our records"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
                <div className="flex flex-wrap gap-2">
                  <Button
                    onClick={() => void decide("approve")}
                    loading={busy === "approve"}
                    disabled={busy !== null}
                  >
                    Approve &amp; activate
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={() => void decide("resubmit")}
                    loading={busy === "resubmit"}
                    disabled={busy !== null}
                  >
                    Request resubmission
                  </Button>
                  <Button
                    variant="danger"
                    onClick={() => void decide("reject")}
                    loading={busy === "reject"}
                    disabled={busy !== null}
                  >
                    Reject
                  </Button>
                </div>
                <p className="text-xs leading-relaxed text-ink-500">
                  Approving activates the {TIER_PLANS[p.tierRequested].name}{" "}
                  membership for {p.months} month{p.months > 1 ? "s" : ""}{" "}
                  immediately (extends the current expiry if one is active).
                  Double approval is impossible — the backend transaction
                  rejects a second decision.
                </p>
              </>
            ) : (
              <div className="space-y-1 text-[13px] text-ink-700">
                <p>
                  Decision: <strong>{p.status.replace(/_/g, " ")}</strong>
                  {p.reviewedAt && <> · {formatDate(p.reviewedAt)}</>}
                </p>
                {p.reviewNote && (
                  <p>
                    <span className="font-bold">Note:</span> {p.reviewNote}
                  </p>
                )}
              </div>
            )}
            {msg && (
              <p
                className={cn(
                  "text-[13px] font-semibold",
                  msg.ok ? "text-success" : "text-danger",
                )}
              >
                {msg.text}
              </p>
            )}
          </div>
        </div>
      )}
    </li>
  );
}

/** Bank details shown to merchants — stored in portalConfig/payments. */
function PaymentSettingsCard() {
  const { data: config, loading } = useDoc(
    doc(db, "portalConfig", "payments"),
    paymentsConfigFromDoc,
  );
  const [form, setForm] = useState<Record<string, string> | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const values = form ?? {
    bankName: config?.bankName ?? "",
    accountName: config?.accountName ?? "",
    accountNumber: config?.accountNumber ?? "",
    branch: config?.branch ?? "",
    instructions: config?.instructions ?? "",
  };

  function set(k: string, v: string) {
    setForm({ ...values, [k]: v });
    setMsg(null);
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await setDoc(doc(db, "portalConfig", "payments"), values, {
        merge: true,
      });
      setMsg({ ok: true, text: "Payment details published to merchants." });
      setForm(null);
    } catch {
      setMsg({ ok: false, text: "Save failed — are you an administrator?" });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader
        title="Payment collection details"
        subtitle="What merchants see on their Payments page"
      />
      <CardBody>
        {loading ? (
          <div className="flex justify-center py-6">
            <Spinner />
          </div>
        ) : (
          <form onSubmit={save} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="Bank"
                value={values.bankName}
                onChange={(e) => set("bankName", e.target.value)}
                placeholder="e.g. Commercial Bank"
              />
              <Input
                label="Branch"
                value={values.branch}
                onChange={(e) => set("branch", e.target.value)}
                placeholder="e.g. Pettah"
              />
              <Input
                label="Account name"
                value={values.accountName}
                onChange={(e) => set("accountName", e.target.value)}
                placeholder="PetaFinds (Pvt) Ltd"
              />
              <Input
                label="Account number"
                value={values.accountNumber}
                onChange={(e) => set("accountNumber", e.target.value)}
                placeholder="XXXXXXXXXX"
              />
            </div>
            <Input
              label="Instructions for merchants"
              value={values.instructions}
              onChange={(e) => set("instructions", e.target.value)}
              placeholder="e.g. Use your business name as the deposit reference"
            />
            {msg && (
              <p
                className={cn(
                  "text-[13px] font-semibold",
                  msg.ok ? "text-success" : "text-danger",
                )}
              >
                {msg.text}
              </p>
            )}
            <Button type="submit" loading={busy} disabled={form === null}>
              Publish details
            </Button>
          </form>
        )}
      </CardBody>
    </Card>
  );
}
