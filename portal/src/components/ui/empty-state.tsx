import { type ReactNode } from "react";

/** Standard empty state — icon, headline, supporting copy, optional CTA. */
export function EmptyState({
  icon,
  title,
  message,
  action,
}: {
  icon?: ReactNode;
  title: string;
  message?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-16 text-center">
      {icon && <div className="text-ink-300 mb-1 [&>svg]:size-10">{icon}</div>}
      <h3 className="font-display font-extrabold text-[15px] text-ink-700">
        {title}
      </h3>
      {message && (
        <p className="max-w-sm text-[13px] leading-relaxed text-ink-500">
          {message}
        </p>
      )}
      {action && <div className="mt-3">{action}</div>}
    </div>
  );
}
