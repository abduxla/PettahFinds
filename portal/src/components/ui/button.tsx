"use client";

import { type ButtonHTMLAttributes, forwardRef } from "react";
import { cn } from "@/lib/cn";
import { Spinner } from "@/components/ui/spinner";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
}

const variants: Record<Variant, string> = {
  primary:
    "bg-teal text-white hover:bg-teal-dark active:bg-teal-dark shadow-sm",
  secondary:
    "bg-surface text-ink-900 border border-line hover:bg-bg-section active:bg-bg-section",
  ghost: "bg-transparent text-ink-700 hover:bg-bg-section",
  danger: "bg-danger text-white hover:opacity-90 shadow-sm",
};

const sizes: Record<Size, string> = {
  sm: "h-9 px-3.5 text-[13px]",
  md: "h-11 px-5 text-sm",
  lg: "h-[50px] px-6 text-[15px]",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  function Button(
    { variant = "primary", size = "md", loading, className, children, disabled, ...rest },
    ref,
  ) {
    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={cn(
          "inline-flex items-center justify-center gap-2 rounded-(--radius-input) font-semibold",
          "transition-all duration-200 ease-(--ease-apple)",
          "disabled:opacity-50 disabled:pointer-events-none select-none cursor-pointer",
          variants[variant],
          sizes[size],
          className,
        )}
        {...rest}
      >
        {loading && <Spinner className="size-4" light={variant === "primary" || variant === "danger"} />}
        {children}
      </button>
    );
  },
);
