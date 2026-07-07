"use client";

import { collection, orderBy, query } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useQuerySub } from "@/lib/firestore-hooks";
import { businessFromDoc, type Business } from "@/lib/types";

/**
 * Every business, newest first — admin-only (rules gate reads of
 * unverified docs to admins). One live subscription shared by the admin
 * dashboard and the businesses table.
 *
 * Mirrors the mobile app's streamAllIncludingPending(). Fine at the
 * current directory size; swap to cursor pagination when the collection
 * grows past a few thousand docs.
 */
export function useAllBusinesses(): {
  data: Business[];
  loading: boolean;
  error: Error | null;
} {
  return useQuerySub(
    query(collection(db, "businesses"), orderBy("createdAt", "desc")),
    businessFromDoc,
    "all-businesses",
  );
}
