import { cn } from "@/lib/cn";

/** PetaFinds wordmark with the brand orange dot (matches the app's logo). */
export function Wordmark({
  className,
  light = false,
}: {
  className?: string;
  light?: boolean;
}) {
  return (
    <span
      className={cn(
        "font-display font-black tracking-tight leading-none select-none",
        light ? "text-white" : "text-teal-dark",
        className,
      )}
    >
      PetaFinds
      <span className="inline-block size-[7px] rounded-full bg-orange ml-0.5 align-super" />
    </span>
  );
}
