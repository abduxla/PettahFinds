"use client";

import { createContext, useContext, type ReactNode } from "react";
import { doc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { useDoc } from "@/lib/firestore-hooks";
import { businessFromDoc, type Business } from "@/lib/types";

/**
 * Live business document for the signed-in owner. Loaded once at the
 * business-portal layout and shared by every page beneath it (a single
 * Firestore listener instead of one per page — minimal reads).
 */
interface BusinessState {
  business: Business | null;
  loading: boolean;
}

const BusinessContext = createContext<BusinessState>({
  business: null,
  loading: true,
});

export function BusinessProvider({ children }: { children: ReactNode }) {
  const { appUser } = useAuth();
  const businessId = appUser?.businessId ?? null;

  const { data, loading } = useDoc(
    businessId ? doc(db, "businesses", businessId) : null,
    businessFromDoc,
  );

  return (
    <BusinessContext.Provider value={{ business: data, loading }}>
      {children}
    </BusinessContext.Provider>
  );
}

export function useBusiness(): BusinessState {
  return useContext(BusinessContext);
}
