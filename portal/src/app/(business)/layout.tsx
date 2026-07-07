"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { BusinessProvider, useBusiness } from "@/lib/business-context";
import { FullScreenSpinner } from "@/components/ui/spinner";
import { PortalShell, type NavItem } from "@/components/shell/portal-shell";
import {
  IconHome,
  IconMembership,
  IconPayments,
} from "@/components/shell/icons";
import { ForcePasswordChange } from "@/components/force-password-change";
import { Button } from "@/components/ui/button";
import { Wordmark } from "@/components/shell/brand";

const NAV: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: IconHome },
  { href: "/membership", label: "Membership", icon: IconMembership },
  { href: "/payments", label: "Payments", icon: IconPayments },
];

/**
 * Business portal gate. Order of checks mirrors the mobile app's redirect:
 *  1. unauthenticated → /sign-in
 *  2. admin → /admin (admins have their own shell)
 *  3. customer accounts / no linked business → explainer screen (the portal
 *     has no self-signup; businesses are onboarded via the app or by admin)
 */
function BusinessGate({ children }: { children: React.ReactNode }) {
  const { fbUser, appUser, loading, signOutPortal } = useAuth();
  const { business, loading: bizLoading } = useBusiness();
  const router = useRouter();

  const isAdmin = appUser?.role === "admin";

  useEffect(() => {
    if (loading) return;
    if (!fbUser) router.replace("/sign-in");
    else if (isAdmin) router.replace("/admin");
  }, [loading, fbUser, isAdmin, router]);

  if (loading || !fbUser || isAdmin) return <FullScreenSpinner />;

  // Provisioned accounts must replace their temporary password before
  // anything else — this blocks the entire business portal until cleared.
  if (appUser?.mustChangePassword) return <ForcePasswordChange />;

  if (!appUser?.businessId) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-bg px-6 text-center">
        <Wordmark className="text-[24px]" />
        <h1 className="font-display text-xl font-black text-ink-900">
          No business linked to this account
        </h1>
        <p className="max-w-md text-sm leading-relaxed text-ink-500">
          This portal is for registered PetaFinds businesses. If you&apos;ve
          just registered, your listing may still be under review — or sign in
          with the account your business was approved under.
        </p>
        <div className="mt-2 flex gap-3">
          <a href="mailto:support@petafinds.lk">
            <Button variant="secondary">Contact support</Button>
          </a>
          <Button onClick={() => void signOutPortal()}>Sign out</Button>
        </div>
      </div>
    );
  }

  if (bizLoading) return <FullScreenSpinner />;

  return (
    <PortalShell
      nav={NAV}
      contextLabel={business?.businessName ?? "Business Portal"}
    >
      {children}
    </PortalShell>
  );
}

export default function BusinessLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <BusinessProvider>
      <BusinessGate>{children}</BusinessGate>
    </BusinessProvider>
  );
}
