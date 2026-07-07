"use client";

import { useBusiness } from "@/lib/business-context";
import {
  effectiveTier,
  TIER_ORDER,
  TIER_PLANS,
} from "@/config/tiers";
import { daysUntil, formatDate, formatLkr } from "@/lib/format";
import { Card, CardBody } from "@/components/ui/card";
import { Badge, TierBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/cn";

/** WhatsApp upgrade line — replaced by the in-portal upgrade request flow
 *  (upgradeRequests collection) in the payments module. */
const SUPPORT_WHATSAPP = "94777128291";

export default function MembershipPage() {
  const { business } = useBusiness();
  if (!business) return null;

  const effective = effectiveTier(business.tier, business.tierValidUntil);
  const days = daysUntil(business.tierValidUntil);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Membership
        </h1>
        <p className="mt-0.5 text-sm text-ink-500">
          Your current plan and everything you can grow into.
        </p>
      </div>

      {/* Current plan summary */}
      <Card>
        <CardBody className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <TierBadge tier={effective} />
            <div>
              <p className="font-display text-lg font-black text-ink-900">
                {TIER_PLANS[effective].name}
              </p>
              <p className="text-[13px] text-ink-500">
                {TIER_PLANS[effective].tagline}
              </p>
            </div>
          </div>
          <div className="text-right text-[13px] text-ink-500">
            {effective === "listed" ? (
              <p>Free plan — no expiry</p>
            ) : (
              <>
                <p>
                  Renews {formatDate(business.tierValidUntil)}
                  {days !== null && (
                    <span className="font-semibold text-ink-700">
                      {" "}
                      · {days} day{days === 1 ? "" : "s"} left
                    </span>
                  )}
                </p>
              </>
            )}
          </div>
        </CardBody>
      </Card>

      {/* Comparison grid */}
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {TIER_ORDER.map((id) => {
          const plan = TIER_PLANS[id];
          const isCurrent = id === effective;
          return (
            <Card
              key={id}
              className={cn(
                "relative flex flex-col",
                isCurrent && "ring-2 ring-teal border-transparent",
              )}
            >
              {plan.ribbon && (
                <span
                  className={cn(
                    "absolute -top-2.5 left-1/2 -translate-x-1/2 rounded-full px-3 py-0.5 text-[10px] font-black tracking-wider text-white",
                    plan.ribbon === "MOST POPULAR"
                      ? "bg-orange"
                      : "bg-tier-vibranium",
                  )}
                >
                  {plan.ribbon === "MARKET LEADER" ? "👑 " : "★ "}
                  {plan.ribbon}
                </span>
              )}
              <CardBody className="flex flex-1 flex-col gap-4 pt-6">
                <div>
                  <div className="flex items-center justify-between">
                    <h3
                      className="font-display text-lg font-black"
                      style={{ color: plan.colorVar }}
                    >
                      {plan.name}
                    </h3>
                    {isCurrent && <Badge tone="teal">Current</Badge>}
                  </div>
                  <p className="mt-1 min-h-9 text-xs leading-relaxed text-ink-500">
                    {plan.tagline}
                  </p>
                </div>
                <div>
                  <span className="font-display text-2xl font-black text-ink-900">
                    {plan.priceLkr === 0 ? "FREE" : formatLkr(plan.priceLkr)}
                  </span>
                  {plan.priceLkr > 0 && (
                    <span className="text-xs font-semibold text-ink-500">
                      {" "}
                      /month
                    </span>
                  )}
                </div>
                <ul className="flex-1 space-y-2">
                  {plan.features.map((f) => (
                    <li
                      key={f}
                      className="flex items-start gap-2 text-[13px] text-ink-700"
                    >
                      <svg
                        viewBox="0 0 20 20"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2.2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="mt-0.5 size-3.5 shrink-0 text-teal"
                      >
                        <path d="m4 10.5 4 4 8-9" />
                      </svg>
                      {f}
                    </li>
                  ))}
                </ul>
                {isCurrent ? (
                  <Button variant="secondary" disabled className="w-full">
                    Your current plan
                  </Button>
                ) : (
                  <a
                    href={`https://wa.me/${SUPPORT_WHATSAPP}?text=${encodeURIComponent(
                      `Hi PetaFinds! I'd like to upgrade "${business.businessName}" to the ${plan.name} plan.`,
                    )}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="block"
                  >
                    <Button className="w-full">
                      {plan.priceLkr === 0 ? "Downgrade" : "Upgrade"} — talk to
                      us
                    </Button>
                  </a>
                )}
              </CardBody>
            </Card>
          );
        })}
      </div>

      <p className="text-center text-xs text-ink-500">
        Prices in Sri Lankan Rupees. Plan changes are activated by the
        PetaFinds team once payment is confirmed — in-portal payment
        submission is coming to this page soon.
      </p>
    </div>
  );
}
