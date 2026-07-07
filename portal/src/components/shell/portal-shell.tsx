"use client";

import { useState, type ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/cn";
import { useAuth } from "@/lib/auth-context";
import { Wordmark } from "@/components/shell/brand";

export interface NavItem {
  href: string;
  label: string;
  icon: ReactNode;
}

/**
 * Shared dashboard chrome: fixed sidebar (collapsible to a drawer on
 * mobile), top bar with context title + account menu. Both the business
 * and admin portals compose this with their own nav items.
 */
export function PortalShell({
  nav,
  contextLabel,
  children,
}: {
  nav: NavItem[];
  /** Small label under the wordmark: business name / "Administration". */
  contextLabel: string;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const { appUser, signOutPortal } = useAuth();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="px-5 pt-6 pb-5">
        <Wordmark className="text-[22px]" />
        <p className="mt-1 truncate text-xs font-semibold text-ink-500">
          {contextLabel}
        </p>
      </div>
      <nav className="flex-1 space-y-0.5 px-3">
        {nav.map((item) => {
          const active =
            pathname === item.href ||
            (item.href !== "/" && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setDrawerOpen(false)}
              className={cn(
                "flex items-center gap-3 rounded-(--radius-input) px-3 py-2.5",
                "text-sm font-semibold transition-colors duration-150",
                active
                  ? "bg-teal-light text-teal-dark"
                  : "text-ink-500 hover:bg-bg-section hover:text-ink-700",
              )}
            >
              <span className="[&>svg]:size-[18px]">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-line px-5 py-4">
        <p className="truncate text-[13px] font-semibold text-ink-700">
          {appUser?.displayName || appUser?.email}
        </p>
        <button
          onClick={() => void signOutPortal()}
          className="mt-1 cursor-pointer text-xs font-semibold text-ink-500 hover:text-danger transition-colors"
        >
          Sign out
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-screen bg-bg">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 border-r border-line bg-surface lg:block">
        {sidebar}
      </aside>

      {/* Mobile drawer */}
      {drawerOpen && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div
            className="absolute inset-0 bg-ink-900/30"
            onClick={() => setDrawerOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-60 bg-surface shadow-xl">
            {sidebar}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col lg:pl-60">
        {/* Top bar */}
        <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-line bg-surface/80 px-4 backdrop-blur-sm lg:px-8">
          <button
            className="rounded-md p-1.5 text-ink-500 hover:bg-bg-section lg:hidden"
            onClick={() => setDrawerOpen(true)}
            aria-label="Open menu"
          >
            <svg viewBox="0 0 20 20" fill="none" className="size-5" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round">
              <path d="M3 5h14M3 10h14M3 15h14" />
            </svg>
          </button>
          <div className="flex-1" />
          <div className="relative">
            <button
              onClick={() => setMenuOpen((v) => !v)}
              className="flex size-8 cursor-pointer items-center justify-center rounded-full bg-teal text-xs font-extrabold text-white"
              aria-label="Account menu"
            >
              {(appUser?.displayName || appUser?.email || "?")
                .charAt(0)
                .toUpperCase()}
            </button>
            {menuOpen && (
              <>
                <div
                  className="fixed inset-0 z-10"
                  onClick={() => setMenuOpen(false)}
                />
                <div className="absolute right-0 z-20 mt-2 w-56 rounded-(--radius-card) border border-line bg-surface p-1.5 shadow-lg">
                  <div className="px-3 py-2">
                    <p className="truncate text-[13px] font-bold text-ink-900">
                      {appUser?.displayName || "Account"}
                    </p>
                    <p className="truncate text-xs text-ink-500">
                      {appUser?.email}
                    </p>
                  </div>
                  <div className="my-1 border-t border-line" />
                  <button
                    onClick={() => void signOutPortal()}
                    className="w-full cursor-pointer rounded-lg px-3 py-2 text-left text-[13px] font-semibold text-danger hover:bg-danger-soft transition-colors"
                  >
                    Sign out
                  </button>
                </div>
              </>
            )}
          </div>
        </header>

        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 lg:px-8 lg:py-8">
          {children}
        </main>
      </div>
    </div>
  );
}
