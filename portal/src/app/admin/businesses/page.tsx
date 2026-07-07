"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useAllBusinesses } from "@/lib/admin-data";
import { effectiveTier, TIER_ORDER, TIER_PLANS } from "@/config/tiers";
import { formatDate } from "@/lib/format";
import { Card } from "@/components/ui/card";
import { StatusBadge, TierBadge } from "@/components/ui/badge";
import { Spinner } from "@/components/ui/spinner";
import { EmptyState } from "@/components/ui/empty-state";
import { cn } from "@/lib/cn";

type StatusFilter = "all" | "active" | "pending" | "suspended";

const STATUS_TABS: { id: StatusFilter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "active", label: "Active" },
  { id: "pending", label: "Pending" },
  { id: "suspended", label: "Suspended" },
];

export default function AdminBusinessesPage() {
  const router = useRouter();
  const { data: businesses, loading, error } = useAllBusinesses();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<StatusFilter>("all");
  const [tier, setTier] = useState<string>("all");

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return businesses.filter((b) => {
      if (status === "active" && !(b.isVerified && !b.suspended)) return false;
      if (status === "pending" && !(!b.isVerified && !b.suspended))
        return false;
      if (status === "suspended" && !b.suspended) return false;
      if (tier !== "all" && effectiveTier(b.tier, b.tierValidUntil) !== tier)
        return false;
      if (
        q &&
        !b.businessName.toLowerCase().includes(q) &&
        !b.category.toLowerCase().includes(q) &&
        !b.location.toLowerCase().includes(q) &&
        !b.email.toLowerCase().includes(q) &&
        !b.id.toLowerCase().includes(q)
      )
        return false;
      return true;
    });
  }, [businesses, search, status, tier]);

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
        message="Your account may not have administrator access, or the network dropped."
      />
    );
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Businesses
        </h1>
        <p className="mt-0.5 text-sm text-ink-500">
          {businesses.length} registered · {filtered.length} shown
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-(--radius-input) border border-line bg-surface p-1">
          {STATUS_TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setStatus(t.id)}
              className={cn(
                "cursor-pointer rounded-lg px-3.5 py-1.5 text-[13px] font-semibold transition-colors",
                status === t.id
                  ? "bg-teal-light text-teal-dark"
                  : "text-ink-500 hover:text-ink-700",
              )}
            >
              {t.label}
            </button>
          ))}
        </div>

        <select
          value={tier}
          onChange={(e) => setTier(e.target.value)}
          className="h-10 cursor-pointer rounded-(--radius-input) border border-line bg-surface px-3 text-[13px] font-semibold text-ink-700 focus:border-teal focus:outline-none"
          aria-label="Filter by membership tier"
        >
          <option value="all">All tiers</option>
          {TIER_ORDER.map((id) => (
            <option key={id} value={id}>
              {TIER_PLANS[id].name}
            </option>
          ))}
        </select>

        <input
          type="search"
          placeholder="Search name, category, location, email…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="h-10 min-w-60 flex-1 rounded-(--radius-input) border border-line bg-surface px-3.5 text-[13px] text-ink-900 placeholder:text-ink-300 focus:border-teal focus:outline-none focus:ring-2 focus:ring-teal/25"
        />
      </div>

      {/* Table */}
      <Card className="overflow-hidden">
        {filtered.length === 0 ? (
          <EmptyState
            title="No businesses match"
            message="Try a different search term or clear the filters."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-line text-xs font-bold uppercase tracking-wide text-ink-500">
                  <th className="px-6 py-3">Business</th>
                  <th className="px-4 py-3">Category</th>
                  <th className="px-4 py-3">Membership</th>
                  <th className="px-4 py-3">Valid until</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Registered</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line/70">
                {filtered.map((b) => (
                  <tr
                    key={b.id}
                    onClick={() =>
                      router.push(`/admin/business/?id=${encodeURIComponent(b.id)}`)
                    }
                    className="cursor-pointer transition-colors hover:bg-bg-section/60"
                  >
                    <td className="px-6 py-3.5">
                      <p className="font-bold text-ink-900">
                        {b.businessName}
                      </p>
                      <p className="text-xs text-ink-500">
                        {b.location || "—"}
                      </p>
                    </td>
                    <td className="px-4 py-3.5 text-ink-700">
                      {b.category || "—"}
                    </td>
                    <td className="px-4 py-3.5">
                      <TierBadge
                        tier={effectiveTier(b.tier, b.tierValidUntil)}
                      />
                    </td>
                    <td className="px-4 py-3.5 text-ink-700">
                      {effectiveTier(b.tier, b.tierValidUntil) === "listed"
                        ? "—"
                        : formatDate(b.tierValidUntil)}
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge
                        isVerified={b.isVerified}
                        suspended={b.suspended}
                      />
                    </td>
                    <td className="px-4 py-3.5 text-ink-700">
                      {formatDate(b.createdAt)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
