"use client";

import Link from "next/link";
import { useAllBusinesses } from "@/lib/admin-data";
import { effectiveTier } from "@/config/tiers";
import { formatDate } from "@/lib/format";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { StatusBadge, TierBadge } from "@/components/ui/badge";
import { Spinner } from "@/components/ui/spinner";
import { EmptyState } from "@/components/ui/empty-state";
import { Button } from "@/components/ui/button";

export default function AdminDashboardPage() {
  const { data: businesses, loading, error } = useAllBusinesses();

  if (loading) {
    return (
      <div className="flex justify-center py-24">
        <Spinner className="size-7" />
      </div>
    );
  }
  if (error) {
    return (
      <EmptyState
        title="Couldn't load businesses"
        message="Your account may not have administrator access, or the network dropped. Refresh to retry."
      />
    );
  }

  const pending = businesses.filter((b) => !b.isVerified && !b.suspended);
  const active = businesses.filter((b) => b.isVerified && !b.suspended);
  const suspended = businesses.filter((b) => b.suspended);
  const paid = businesses.filter(
    (b) => effectiveTier(b.tier, b.tierValidUntil) !== "listed",
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Dashboard
        </h1>
        <p className="mt-0.5 text-sm text-ink-500">
          Operational overview across all PetaFinds businesses.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat label="Total businesses" value={businesses.length} />
        <Stat label="Active" value={active.length} />
        <Stat
          label="Pending review"
          value={pending.length}
          accent={pending.length > 0 ? "orange" : undefined}
        />
        <Stat label="Paid memberships" value={paid.length} accent="teal" />
      </div>

      {suspended.length > 0 && (
        <p className="text-[13px] font-semibold text-danger">
          {suspended.length} suspended account
          {suspended.length === 1 ? "" : "s"}
        </p>
      )}

      <Card>
        <CardHeader
          title="Review queue"
          subtitle={
            pending.length === 0
              ? "No businesses waiting for approval"
              : `${pending.length} business${pending.length === 1 ? "" : "es"} waiting for approval`
          }
          action={
            <Link href="/admin/businesses">
              <Button variant="ghost" size="sm">
                View all →
              </Button>
            </Link>
          }
        />
        <CardBody className="px-0 pb-2 pt-3">
          {pending.length === 0 ? (
            <EmptyState
              title="Queue is clear"
              message="New registrations will appear here for verification."
            />
          ) : (
            <ul className="divide-y divide-line/70">
              {pending.slice(0, 6).map((b) => (
                <li
                  key={b.id}
                  className="flex items-center justify-between gap-4 px-6 py-3"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-bold text-ink-900">
                      {b.businessName}
                    </p>
                    <p className="truncate text-xs text-ink-500">
                      {b.category || "—"} · {b.location || "—"} · submitted{" "}
                      {formatDate(b.createdAt)}
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <TierBadge tier={b.tier} />
                    <StatusBadge isVerified={b.isVerified} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Card>
    </div>
  );
}

function Stat({
  label,
  value,
  accent,
}: {
  label: string;
  value: number;
  accent?: "orange" | "teal";
}) {
  return (
    <Card>
      <CardBody className="px-5 py-4">
        <p className="text-xs font-bold uppercase tracking-wide text-ink-500">
          {label}
        </p>
        <p
          className={`mt-1 font-display text-2xl font-black ${
            accent === "orange"
              ? "text-orange"
              : accent === "teal"
                ? "text-teal"
                : "text-ink-900"
          }`}
        >
          {value}
        </p>
      </CardBody>
    </Card>
  );
}
