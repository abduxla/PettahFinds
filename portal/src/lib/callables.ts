import { httpsCallable } from "firebase/functions";
import { FirebaseError } from "firebase/app";
import { functions } from "@/lib/firebase";

/**
 * Typed wrappers around the portal's Cloud Functions callables.
 * All of these are deployed with enforceAppCheck — see firebase.ts for
 * the web App Check setup requirement.
 */

interface ProvisionResult {
  ok: boolean;
  email: string;
  /** true = new account created; false = existing password reset. */
  created: boolean;
}

export async function provisionPortalAccess(
  businessId: string,
): Promise<ProvisionResult> {
  const fn = httpsCallable<{ businessId: string }, ProvisionResult>(
    functions,
    "provisionPortalAccess",
  );
  const res = await fn({ businessId });
  return res.data;
}

/** Human-readable message from a callable failure. */
export function callableError(err: unknown): string {
  if (err instanceof FirebaseError) {
    // functions/* codes carry our server-authored messages — surface them.
    if (err.message && !err.message.startsWith("internal")) return err.message;
  }
  return "Something went wrong. Please try again.";
}
