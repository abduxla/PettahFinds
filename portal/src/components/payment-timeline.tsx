import { cn } from "@/lib/cn";
import type { PaymentStatus } from "@/lib/payments";

/**
 * Progress rail for a payment:
 *   Submitted → Pending Verification → Approved → Membership Activated
 * Approval activates the membership in the same backend transaction, so
 * steps 3 and 4 complete together. Rejection/resubmission renders the
 * third step in its failure state instead.
 */
export function PaymentTimeline({ status }: { status: PaymentStatus }) {
  const failed = status === "rejected" || status === "resubmission_requested";
  const steps: {
    label: string;
    state: "done" | "active" | "failed" | "todo";
  }[] = [
    { label: "Submitted", state: "done" },
    {
      label: "Pending Verification",
      state:
        status === "pending_verification"
          ? "active"
          : failed
            ? "done"
            : "done",
    },
    {
      label: failed
        ? status === "rejected"
          ? "Rejected"
          : "Resubmission Requested"
        : "Approved",
      state: failed ? "failed" : status === "approved" ? "done" : "todo",
    },
    {
      label: "Membership Activated",
      state: status === "approved" ? "done" : "todo",
    },
  ];

  return (
    <ol className="flex flex-wrap items-center gap-y-2">
      {steps.map((step, i) => (
        <li key={step.label} className="flex items-center">
          {i > 0 && (
            <span
              className={cn(
                "mx-2 h-px w-6 sm:w-10",
                step.state === "todo" ? "bg-line" : "bg-teal/40",
              )}
            />
          )}
          <span className="flex items-center gap-1.5">
            <span
              className={cn(
                "flex size-4 items-center justify-center rounded-full text-[9px] font-black",
                step.state === "done" && "bg-teal text-white",
                step.state === "active" &&
                  "bg-orange text-white animate-pulse",
                step.state === "failed" && "bg-danger text-white",
                step.state === "todo" && "border border-line bg-surface",
              )}
            >
              {step.state === "done" && "✓"}
              {step.state === "failed" && "✕"}
            </span>
            <span
              className={cn(
                "text-xs font-semibold whitespace-nowrap",
                step.state === "todo" ? "text-ink-300" : "text-ink-700",
                step.state === "failed" && "text-danger",
                step.state === "active" && "text-orange",
              )}
            >
              {step.label}
            </span>
          </span>
        </li>
      ))}
    </ol>
  );
}
