/** Formatting helpers shared across the portal. */

const lkr = new Intl.NumberFormat("en-LK", { maximumFractionDigits: 0 });

/** "LKR 5,490" — matches the mobile app's formatLkr convention. */
export function formatLkr(amount: number): string {
  return `LKR ${lkr.format(amount)}`;
}

const dateFmt = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
});

const dateTimeFmt = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

export function formatDate(d: Date | null): string {
  return d ? dateFmt.format(d) : "—";
}

export function formatDateTime(d: Date | null): string {
  return d ? dateTimeFmt.format(d) : "—";
}

/** Whole days from now until `d` (negative = past). */
export function daysUntil(d: Date | null): number | null {
  if (!d) return null;
  const ms = d.getTime() - Date.now();
  return Math.ceil(ms / 86_400_000);
}
