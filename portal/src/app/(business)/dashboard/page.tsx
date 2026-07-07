"use client";

import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { useBusiness } from "@/lib/business-context";
import { effectiveTier, planOf, TIER_PLANS } from "@/config/tiers";
import { daysUntil, formatDate, formatDateTime, formatLkr } from "@/lib/format";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Badge, StatusBadge, TierBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export default function DashboardPage() {
  const { fbUser } = useAuth();
  const { business } = useBusiness();
  if (!business) return null;

  const assignedPlan = planOf(business.tier);
  const effective = effectiveTier(business.tier, business.tierValidUntil);
  const effectivePlan = TIER_PLANS[effective];
  const expired = assignedPlan.id !== "listed" && effective === "listed";
  const days = daysUntil(business.tierValidUntil);
  const expiringSoon =
    !expired && effective !== "listed" && days !== null && days <= 30;

  const lastLogin = fbUser?.metadata.lastSignInTime
    ? formatDateTime(new Date(fbUser.metadata.lastSignInTime))
    : "—";

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
            {business.businessName}
          </h1>
          <p className="mt-0.5 text-sm text-ink-500">
            {business.category || "Business"} · {business.location || "Pettah"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <TierBadge tier={effective} />
          <StatusBadge
            isVerified={business.isVerified}
            suspended={business.suspended}
          />
        </div>
      </div>

      {/* Warning banners */}
      {business.suspended && (
        <Banner tone="danger" title="Your account is suspended">
          Your listing is currently hidden from customers. Contact PetaFinds
          support to resolve this.
        </Banner>
      )}
      {!business.suspended && !business.isVerified && (
        <Banner tone="orange" title="Your listing is under review">
          Our team is verifying your business details. You&apos;ll be notified
          once your listing goes live — typically within 24–48 hours.
        </Banner>
      )}
      {expired && (
        <Banner tone="danger" title="Your membership has expired">
          Your {assignedPlan.name} benefits ended on{" "}
          {formatDate(business.tierValidUntil)} and your listing has moved to
          the free Silver plan. Renew to restore your benefits.
        </Banner>
      )}
      {expiringSoon && (
        <Banner
          tone="orange"
          title={`Your ${effectivePlan.name} membership expires in ${days} day${days === 1 ? "" : "s"}`}
        >
          Renew before {formatDate(business.tierValidUntil)} to keep your
          benefits without interruption.
        </Banner>
      )}

      {/* Stat row */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat
          label="Membership"
          value={effectivePlan.name}
          sub={
            effectivePlan.priceLkr === 0
              ? "Free plan"
              : `${formatLkr(effectivePlan.priceLkr)} / month`
          }
        />
        <Stat
          label="Valid until"
          value={
            effective === "listed" ? "—" : formatDate(business.tierValidUntil)
          }
          sub={
            effective !== "listed" && days !== null
              ? `${days} day${days === 1 ? "" : "s"} remaining`
              : "No expiry on the free plan"
          }
        />
        <Stat
          label="Rating"
          value={
            business.ratingCount > 0 ? business.ratingAvg.toFixed(1) : "—"
          }
          sub={`${business.ratingCount} review${business.ratingCount === 1 ? "" : "s"}`}
        />
        <Stat
          label="Product limit"
          value={
            effectivePlan.productCap === null
              ? "Unlimited"
              : String(effectivePlan.productCap)
          }
          sub="Active listings allowed"
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Membership card */}
        <Card>
          <CardHeader
            title="Your membership"
            subtitle="Plan, benefits and renewal"
            action={<TierBadge tier={effective} />}
          />
          <CardBody className="space-y-4">
            <div className="space-y-2 text-sm">
              <Row label="Current plan" value={effectivePlan.name} />
              <Row
                label="Monthly fee"
                value={
                  effectivePlan.priceLkr === 0
                    ? "Free"
                    : formatLkr(effectivePlan.priceLkr)
                }
              />
              <Row
                label="Status"
                value={
                  expired ? (
                    <Badge tone="danger">Expired</Badge>
                  ) : effective === "listed" ? (
                    <Badge tone="neutral">Active — Free</Badge>
                  ) : (
                    <Badge tone="success">Active</Badge>
                  )
                }
              />
              <Row
                label="Renewal date"
                value={
                  effective === "listed"
                    ? "—"
                    : formatDate(business.tierValidUntil)
                }
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Link href="/membership" className="block">
                <Button variant="secondary" className="w-full">
                  View plans
                </Button>
              </Link>
              <Link href="/payments" className="block">
                <Button className="w-full">
                  {expired || expiringSoon ? "Renew now" : "Make a payment"}
                </Button>
              </Link>
            </div>
          </CardBody>
        </Card>

        {/* Account card */}
        <Card>
          <CardHeader
            title="Account"
            subtitle="Sign-in and contact details"
          />
          <CardBody className="space-y-2 text-sm">
            <Row label="Owner" value={business.ownerName || "—"} />
            <Row label="Business email" value={business.email || "—"} />
            <Row label="Phone" value={business.phone || "—"} />
            <Row label="Last sign-in" value={lastLogin} />
          </CardBody>
        </Card>
      </div>
    </div>
  );
}

function Banner({
  tone,
  title,
  children,
}: {
  tone: "orange" | "danger";
  title: string;
  children: React.ReactNode;
}) {
  const styles =
    tone === "danger"
      ? "border-danger/25 bg-danger-soft [--accent:var(--color-danger)]"
      : "border-orange/25 bg-orange-soft [--accent:var(--color-orange)]";
  return (
    <div
      role="status"
      className={`rounded-(--radius-card) border border-l-4 border-l-(--accent) px-5 py-4 ${styles}`}
    >
      <p className="text-sm font-bold text-(--accent)">{title}</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-700">
        {children}
      </p>
    </div>
  );
}

function Stat({
  label,
  value,
  sub,
}: {
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <Card>
      <CardBody className="px-5 py-4">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-500">
          {label}
        </p>
        <p className="mt-1 font-display text-xl font-black text-ink-900">
          {value}
        </p>
        {sub && <p className="mt-0.5 text-xs text-ink-500">{sub}</p>}
      </CardBody>
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
    <div className="flex items-center justify-between gap-4 border-b border-line/60 pb-2 last:border-0 last:pb-0">
      <span className="text-ink-500">{label}</span>
      <span className="text-right font-semibold text-ink-900">{value}</span>
    </div>
  );
}
