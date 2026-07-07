"use client";

import { useEffect, useState } from "react";
import {
  onSnapshot,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Query,
} from "firebase/firestore";

/**
 * Live-subscription hooks. Real-time by design: the mobile app streams
 * everything, and the portal must reflect the same live truth (payment
 * status flips, tier changes) without refresh.
 *
 * Loading state is DERIVED at render (last snapshot's identity vs the
 * current subscription's) rather than set inside effects, so the hooks
 * stay compliant with react-hooks/set-state-in-effect.
 */

interface DocState<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
}

export function useDoc<T>(
  ref: DocumentReference<DocumentData> | null,
  convert: (snap: DocumentSnapshot<DocumentData>) => T | null,
): DocState<T> {
  const path = ref?.path ?? null;
  const [result, setResult] = useState<{
    path: string;
    data: T | null;
    error: Error | null;
  } | null>(null);

  useEffect(() => {
    if (!ref) return;
    return onSnapshot(
      ref,
      (snap) => setResult({ path: ref.path, data: convert(snap), error: null }),
      (err) => setResult({ path: ref.path, data: null, error: err }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps -- resubscribe by path, not object identity
  }, [path]);

  if (!path) return { data: null, loading: false, error: null };
  if (!result || result.path !== path)
    return { data: null, loading: true, error: null };
  return { data: result.data, loading: false, error: result.error };
}

interface ColState<T> {
  data: T[];
  loading: boolean;
  error: Error | null;
}

export function useQuerySub<T>(
  q: Query<DocumentData> | null,
  convert: (snap: DocumentSnapshot<DocumentData>) => T | null,
  /** Stable identity for the query; change it to force a resubscribe. */
  key: string,
): ColState<T> {
  const [result, setResult] = useState<{
    key: string;
    data: T[];
    error: Error | null;
  } | null>(null);

  useEffect(() => {
    if (!q) return;
    return onSnapshot(
      q,
      (snap) =>
        setResult({
          key,
          data: snap.docs
            .map((d) => convert(d))
            .filter((x): x is T => x !== null),
          error: null,
        }),
      (err) => setResult({ key, data: [], error: err }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps -- resubscribe by caller-provided key
  }, [key]);

  if (!q) return { data: [], loading: false, error: null };
  if (!result || result.key !== key)
    return { data: [], loading: true, error: null };
  return { data: result.data, loading: false, error: result.error };
}
