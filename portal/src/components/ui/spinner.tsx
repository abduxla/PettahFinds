import { cn } from "@/lib/cn";

export function Spinner({
  className,
  light = false,
}: {
  className?: string;
  light?: boolean;
}) {
  return (
    <span
      role="status"
      aria-label="Loading"
      className={cn(
        "inline-block size-5 animate-spin rounded-full border-2 border-transparent",
        light ? "border-t-white border-r-white" : "border-t-teal border-r-teal",
        className,
      )}
    />
  );
}

/** Full-viewport centered spinner for gate/loading states. */
export function FullScreenSpinner() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-bg">
      <Spinner className="size-7" />
    </div>
  );
}
