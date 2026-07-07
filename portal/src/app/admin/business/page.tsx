"use client";

import { Suspense, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import {
  deleteField,
  doc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useDoc } from "@/lib/firestore-hooks";
import { businessFromDoc, type Business } from "@/lib/types";
import {
  TIER_ORDER,
  TIER_PLANS,
  effectiveTier,
  type TierId,
} from "@/config/tiers";
import { formatDate, formatLkr } from "@/lib/format";
import { provisionPortalAccess, callableError } from "@/lib/callables";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Badge, StatusBadge, TierBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { FullScreenSpinner, Spinner } from "@/components/ui/spinner";
import { EmptyState } from "@/components/ui/empty-state";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";

/** Last day of the current month, 23:59 local — mirrors the mobile admin
 *  screen's default tier expiry. */
function endOfCurrentMonth(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 0);
}

function toDateInputValue(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export default function AdminBusinessDetailPage() {
  return (
    <Suspense fallback={<FullScreenSpinner />}>
      <BusinessDetail />
    </Suspense>
  );
}

function BusinessDetail() {
  const params = useSearchParams();
  const id = params.get("id");
  const { data: business, loading } = useDoc(
    id ? doc(db, "businesses", id) : null,
    businessFromDoc,
  );

  if (!id) {
    return (
      <EmptyState
        title="No business selected"
        message="Open a business from the Businesses list."
        action={
          <Link href="/admin/businesses">
            <Button variant="secondary">Go to Businesses</Button>
          </Link>
        }
      />
    );
  }
  if (loading) {
    return (
      <div className="flex justify-center py-24">
        <Spinner className="size-7" />
      </div>
    );
  }
  if (!business) {
    return (
      <EmptyState
        title="Business not found"
        message="It may have been deleted."
        action={
          <Link href="/admin/businesses">
            <Button variant="secondary">Back to Businesses</Button>
          </Link>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <Link
        href="/admin/businesses"
        className="text-[13px] font-semibold text-ink-500 hover:text-teal transition-colors"
      >
        ← Businesses
      </Link>

      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          {business.logoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- static export, remote Storage URL
            <img
              src={business.logoUrl}
              alt=""
              className="size-14 rounded-(--radius-card) border border-line object-cover"
            />
          ) : (
            <div className="flex size-14 items-center justify-center rounded-(--radius-card) bg-teal-light font-display text-lg font-black text-teal-dark">
              {business.businessName.charAt(0).toUpperCase() || "?"}
            </div>
          )}
          <div>
            <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
              {business.businessName}
            </h1>
            <p className="mt-0.5 text-sm text-ink-500">
              {business.category || "—"} · {business.location || "—"} ·
              registered {formatDate(business.createdAt)}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <TierBadge tier={effectiveTier(business.tier, business.tierValidUntil)} />
          <StatusBadge
            isVerified={business.isVerified}
            suspended={business.suspended}
          />
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <ProfileCard business={business} />
        <VerificationCard business={business} />
        <MembershipCard business={business} />
        <PortalAccessCard business={business} />
      </div>
    </div>
  );
}

function ProfileCard({ business }: { business: Business }) {
  return (
    <Card>
      <CardHeader title="Business profile" subtitle="As shown in the app" />
      <CardBody className="space-y-2 text-sm">
        <Row label="Owner" value={business.ownerName || "—"} />
        <Row label="Owner phone" value={business.ownerPhone || "—"} />
        <Row label="Business email" value={business.email || "—"} />
        <Row label="Phone" value={business.phone || "—"} />
        <Row label="WhatsApp" value={business.whatsappNumber || "—"} />
        <Row
          label="Rating"
          value={
            business.ratingCount > 0
              ? `${business.ratingAvg.toFixed(1)} (${business.ratingCount} reviews)`
              : "No reviews yet"
          }
        />
        <Row
          label="Description"
          value={
            <span className="line-clamp-3 text-left">
              {business.description || "—"}
            </span>
          }
        />
      </CardBody>
    </Card>
  );
}

/** Approve / un-approve / suspend / reactivate. Suspension both flags the
 *  account AND un-verifies it, so the live mobile app hides the listing
 *  immediately (customer reads require isVerified == true). */
function VerificationCard({ business }: { business: Business }) {
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<"approve" | "unapprove" | "suspend" | "activate" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const ref = doc(db, "businesses", business.id);

  async function run(update: Record<string, unknown>) {
    setBusy(true);
    setError(null);
    try {
      await updateDoc(ref, update);
      setConfirm(null);
    } catch {
      setError("Update failed — check your connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader
        title="Verification & status"
        subtitle="Controls what customers can see"
      />
      <CardBody className="space-y-4">
        <div className="space-y-2 text-sm">
          <Row
            label="Listing"
            value={
              business.suspended ? (
                <Badge tone="danger">Suspended — hidden</Badge>
              ) : business.isVerified ? (
                <Badge tone="success">Live in the app</Badge>
              ) : (
                <Badge tone="orange">Hidden — pending approval</Badge>
              )
            }
          />
        </div>
        {error && (
          <p className="text-[13px] font-semibold text-danger">{error}</p>
        )}
        <div className="flex flex-wrap gap-3">
          {!business.suspended && !business.isVerified && (
            <Button onClick={() => setConfirm("approve")}>
              Approve listing
            </Button>
          )}
          {!business.suspended && business.isVerified && (
            <Button variant="secondary" onClick={() => setConfirm("unapprove")}>
              Un-approve
            </Button>
          )}
          {!business.suspended ? (
            <Button variant="danger" onClick={() => setConfirm("suspend")}>
              Suspend account
            </Button>
          ) : (
            <Button onClick={() => setConfirm("activate")}>
              Reactivate account
            </Button>
          )}
        </div>
      </CardBody>

      <ConfirmDialog
        open={confirm === "approve"}
        title="Approve this business?"
        body={
          <>
            <strong>{business.businessName}</strong> becomes visible to all
            customers, and the owner is notified by push + email.
          </>
        }
        confirmLabel="Approve"
        busy={busy}
        onConfirm={() => void run({ isVerified: true })}
        onCancel={() => setConfirm(null)}
      />
      <ConfirmDialog
        open={confirm === "unapprove"}
        title="Un-approve this business?"
        body="The listing is hidden from customers until approved again."
        confirmLabel="Un-approve"
        tone="danger"
        busy={busy}
        onConfirm={() => void run({ isVerified: false })}
        onCancel={() => setConfirm(null)}
      />
      <ConfirmDialog
        open={confirm === "suspend"}
        title="Suspend this account?"
        body={
          <>
            <strong>{business.businessName}</strong> is immediately hidden
            from customers and flagged as suspended in both portals. The
            owner keeps portal access to resolve the issue.
          </>
        }
        confirmLabel="Suspend"
        tone="danger"
        busy={busy}
        onConfirm={() => void run({ suspended: true, isVerified: false })}
        onCancel={() => setConfirm(null)}
      />
      <ConfirmDialog
        open={confirm === "activate"}
        title="Reactivate this account?"
        body="Clears the suspension and re-approves the listing — it becomes visible to customers again."
        confirmLabel="Reactivate"
        busy={busy}
        onConfirm={() => void run({ suspended: false, isVerified: true })}
        onCancel={() => setConfirm(null)}
      />
    </Card>
  );
}

/** Assign membership level + expiry — the portal twin of the mobile admin's
 *  setTier (same field semantics: tier + tierValidUntil, expiry removed on
 *  the free tier). */
function MembershipCard({ business }: { business: Business }) {
  const [tier, setTier] = useState<TierId>(business.tier);
  const [validUntil, setValidUntil] = useState<string>(
    toDateInputValue(business.tierValidUntil ?? endOfCurrentMonth()),
  );
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const dirty =
    tier !== business.tier ||
    (tier !== "listed" &&
      validUntil !==
        toDateInputValue(business.tierValidUntil ?? endOfCurrentMonth()));

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const update: Record<string, unknown> =
        tier === "listed"
          ? { tier, tierValidUntil: deleteField() }
          : {
              tier,
              tierValidUntil: Timestamp.fromDate(
                new Date(`${validUntil}T23:59:00`),
              ),
            };
      await updateDoc(doc(db, "businesses", business.id), update);
      setMsg({ ok: true, text: "Membership updated." });
    } catch {
      setMsg({ ok: false, text: "Update failed — try again." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader
        title="Membership"
        subtitle="Assign the plan and its renewal date"
        action={<TierBadge tier={effectiveTier(business.tier, business.tierValidUntil)} />}
      />
      <CardBody className="space-y-4">
        <div className="grid grid-cols-2 gap-2">
          {TIER_ORDER.map((id) => {
            const plan = TIER_PLANS[id];
            const selected = tier === id;
            return (
              <button
                key={id}
                onClick={() => {
                  setTier(id);
                  setMsg(null);
                }}
                className={`cursor-pointer rounded-(--radius-input) border px-3 py-2.5 text-left transition-all duration-150 ${
                  selected
                    ? "border-teal bg-teal-light"
                    : "border-line bg-surface hover:border-ink-300"
                }`}
              >
                <p
                  className="text-sm font-black"
                  style={{ color: plan.colorVar }}
                >
                  {plan.name}
                </p>
                <p className="text-xs text-ink-500">
                  {plan.priceLkr === 0
                    ? "Free"
                    : `${formatLkr(plan.priceLkr)}/mo`}
                </p>
              </button>
            );
          })}
        </div>

        {tier !== "listed" && (
          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="tier-valid-until"
              className="text-[13px] font-semibold text-ink-700"
            >
              Valid until
            </label>
            <input
              id="tier-valid-until"
              type="date"
              value={validUntil}
              min={toDateInputValue(new Date())}
              onChange={(e) => {
                setValidUntil(e.target.value);
                setMsg(null);
              }}
              className="h-11 rounded-(--radius-input) border border-line bg-surface px-4 text-sm text-ink-900 focus:border-teal focus:outline-none focus:ring-2 focus:ring-teal/25"
            />
          </div>
        )}

        {msg && (
          <p
            className={`text-[13px] font-semibold ${msg.ok ? "text-success" : "text-danger"}`}
          >
            {msg.text}
          </p>
        )}

        <Button
          onClick={() => void save()}
          loading={busy}
          disabled={!dirty}
          className="w-full"
        >
          Save membership
        </Button>
      </CardBody>
    </Card>
  );
}

/** Create / reset the owner's portal credentials via the
 *  provisionPortalAccess callable. The temp password goes to the business
 *  email only — it never travels through this UI. */
function PortalAccessCard({ business }: { business: Business }) {
  const [busy, setBusy] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const hasOwner = !!business.ownerUid;
  const hasEmail = !!business.email;

  async function provision() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await provisionPortalAccess(business.id);
      setMsg({
        ok: true,
        text: res.created
          ? `Portal account created — credentials emailed to ${res.email}.`
          : `Password reset — new credentials emailed to ${res.email}.`,
      });
      setConfirmOpen(false);
    } catch (err) {
      setMsg({ ok: false, text: callableError(err) });
      setConfirmOpen(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader
        title="Portal access"
        subtitle="Owner sign-in for this portal"
      />
      <CardBody className="space-y-4">
        <div className="space-y-2 text-sm">
          <Row
            label="Owner account"
            value={
              hasOwner ? (
                <Badge tone="success">Linked</Badge>
              ) : (
                <Badge tone="orange">Not linked</Badge>
              )
            }
          />
          <Row label="Sign-in email" value={business.email || "— none on file"} />
        </div>

        <p className="text-xs leading-relaxed text-ink-500">
          {hasOwner
            ? "Sends a new temporary password to the business email and revokes existing sessions. Use when the owner is locked out."
            : "Creates a portal account for the business email, links it as the owner, and emails a temporary password. The owner must change it at first sign-in."}
        </p>

        {msg && (
          <p
            className={`text-[13px] font-semibold ${msg.ok ? "text-success" : "text-danger"}`}
          >
            {msg.text}
          </p>
        )}

        <Button
          onClick={() => setConfirmOpen(true)}
          disabled={!hasEmail}
          variant={hasOwner ? "secondary" : "primary"}
          className="w-full"
        >
          {hasOwner ? "Reset & resend credentials" : "Create portal access"}
        </Button>
        {!hasEmail && (
          <p className="text-xs font-semibold text-danger">
            Add an email address to the business profile first.
          </p>
        )}
      </CardBody>

      <ConfirmDialog
        open={confirmOpen}
        title={hasOwner ? "Reset the owner's password?" : "Create portal access?"}
        body={
          <>
            A new temporary password will be emailed to{" "}
            <strong>{business.email}</strong>.
            {hasOwner &&
              " The owner's current password stops working and active sessions are signed out."}
          </>
        }
        confirmLabel={hasOwner ? "Reset & send" : "Create & send"}
        tone={hasOwner ? "danger" : "primary"}
        busy={busy}
        onConfirm={() => void provision()}
        onCancel={() => setConfirmOpen(false)}
      />
    </Card>
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
    <div className="flex items-start justify-between gap-4 border-b border-line/60 pb-2 last:border-0 last:pb-0">
      <span className="shrink-0 text-ink-500">{label}</span>
      <span className="text-right font-semibold text-ink-900">{value}</span>
    </div>
  );
}
