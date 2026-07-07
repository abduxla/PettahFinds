"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { FullScreenSpinner } from "@/components/ui/spinner";
import { PortalShell, type NavItem } from "@/components/shell/portal-shell";
import {
  IconBuildings,
  IconGauge,
  IconPayments,
} from "@/components/shell/icons";

const NAV: NavItem[] = [
  { href: "/admin", label: "Dashboard", icon: IconGauge },
  { href: "/admin/businesses", label: "Businesses", icon: IconBuildings },
  { href: "/admin/payments", label: "Payments", icon: IconPayments },
];

/**
 * Admin gate. Client-side redirect is UX only — the real enforcement is
 * Firestore rules (isAdmin()): a non-admin reaching this tree simply gets
 * permission-denied on every query.
 */
export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { fbUser, appUser, loading } = useAuth();
  const router = useRouter();

  const isAdmin = appUser?.role === "admin";

  useEffect(() => {
    if (loading) return;
    if (!fbUser) router.replace("/sign-in");
    else if (!isAdmin) router.replace("/dashboard");
  }, [loading, fbUser, isAdmin, router]);

  if (loading || !fbUser || !isAdmin) return <FullScreenSpinner />;

  return (
    <PortalShell nav={NAV} contextLabel="Administration">
      {children}
    </PortalShell>
  );
}
