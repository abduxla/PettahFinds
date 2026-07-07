"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { FullScreenSpinner } from "@/components/ui/spinner";

/**
 * Root landing — routes each identity to its home, mirroring the mobile
 * app's roleHome(): admin → /admin, business → /dashboard, everyone
 * else → /sign-in (customers have no portal surface).
 */
export default function RootPage() {
  const { fbUser, appUser, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (!fbUser) {
      router.replace("/sign-in");
    } else if (appUser?.role === "admin") {
      router.replace("/admin");
    } else {
      router.replace("/dashboard");
    }
  }, [loading, fbUser, appUser, router]);

  return <FullScreenSpinner />;
}
