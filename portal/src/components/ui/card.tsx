import { type HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

/** Standard surface card — radius 16, hairline border, subtle shadow. */
export function Card({
  className,
  ...rest
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "bg-surface rounded-(--radius-card) border border-line",
        "shadow-[0_1px_2px_rgba(17,17,16,0.04)]",
        className,
      )}
      {...rest}
    />
  );
}

export function CardHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-4 px-6 pt-5 pb-0">
      <div>
        <h3 className="font-display font-extrabold text-[17px] text-ink-900 tracking-tight">
          {title}
        </h3>
        {subtitle && (
          <p className="text-[13px] text-ink-500 mt-0.5">{subtitle}</p>
        )}
      </div>
      {action}
    </div>
  );
}

export function CardBody({
  className,
  ...rest
}: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("px-6 py-5", className)} {...rest} />;
}
