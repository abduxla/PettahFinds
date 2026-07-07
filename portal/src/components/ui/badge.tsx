import { type ReactNode } from "react";
import { cn } from "@/lib/cn";
import { planOf } from "@/config/tiers";

type Tone = "neutral" | "teal" | "orange" | "success" | "danger" | "violet";

const tones: Record<Tone, string> = {
  neutral: "bg-bg-section text-ink-700",
  teal: "bg-teal-light text-teal-dark",
  orange: "bg-orange-soft text-orange",
  success: "bg-success-soft text-success",
  danger: "bg-danger-soft text-danger",
  violet: "bg-[#f3edfd] text-tier-vibranium",
};

export function Badge({
  tone = "neutral",
  children,
  className,
}: {
  tone?: Tone;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5",
        "text-xs font-bold whitespace-nowrap",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

const tierTone: Record<string, Tone> = {
  listed: "neutral",
  spotlight: "teal",
  prime: "orange",
  elite: "violet",
};

/** Membership tier pill — shows the commercial name (Silver/Gold/…). */
export function TierBadge({ tier }: { tier: string }) {
  const plan = planOf(tier);
  return <Badge tone={tierTone[plan.id] ?? "neutral"}>{plan.name}</Badge>;
}

/** Verified / pending / suspended status pill for a business. */
export function StatusBadge({
  isVerified,
  suspended,
}: {
  isVerified: boolean;
  suspended?: boolean;
}) {
  if (suspended) return <Badge tone="danger">Suspended</Badge>;
  if (isVerified) return <Badge tone="success">Active</Badge>;
  return <Badge tone="orange">Pending Review</Badge>;
}
