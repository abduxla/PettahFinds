"use client";

import { type ReactNode } from "react";
import { Button } from "@/components/ui/button";

/**
 * Modal confirmation for consequential actions. Rendered conditionally by
 * the caller (`open` short-circuits), so no portal/focus-trap machinery —
 * adequate for the portal's small set of destructive flows.
 */
export function ConfirmDialog({
  open,
  title,
  body,
  confirmLabel,
  tone = "primary",
  busy = false,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  body: ReactNode;
  confirmLabel: string;
  tone?: "primary" | "danger";
  busy?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        className="absolute inset-0 bg-ink-900/40"
        onClick={busy ? undefined : onCancel}
      />
      <div className="relative w-full max-w-md rounded-(--radius-dialog) bg-surface p-6 shadow-xl">
        <h3 className="font-display text-lg font-black text-ink-900">
          {title}
        </h3>
        <div className="mt-2 text-sm leading-relaxed text-ink-700">{body}</div>
        <div className="mt-6 flex justify-end gap-3">
          <Button variant="secondary" onClick={onCancel} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant={tone === "danger" ? "danger" : "primary"}
            onClick={onConfirm}
            loading={busy}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
