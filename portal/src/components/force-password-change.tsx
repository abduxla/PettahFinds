"use client";

import { useState, type FormEvent } from "react";
import {
  EmailAuthProvider,
  reauthenticateWithCredential,
  updatePassword,
} from "firebase/auth";
import { FirebaseError } from "firebase/app";
import { doc, updateDoc } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Wordmark } from "@/components/shell/brand";

/**
 * Full-screen blocking flow shown while users/{uid}.mustChangePassword is
 * true (set by provisionPortalAccess). The user proves possession of the
 * temporary password (reauthentication), sets a new one, and the flag is
 * cleared — rules allow the owner to transition it to false only.
 */
export function ForcePasswordChange() {
  const { fbUser, signOutPortal } = useAuth();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function validate(): string | null {
    if (next.length < 8) return "New password must be at least 8 characters.";
    if (!/[a-zA-Z]/.test(next) || !/[0-9]/.test(next))
      return "New password must include at least one letter and one number.";
    if (next === current)
      return "New password must be different from the temporary one.";
    if (next !== confirm) return "Passwords don't match.";
    return null;
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const user = auth.currentUser;
    if (!user?.email) return;

    const v = validate();
    if (v) {
      setError(v);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await reauthenticateWithCredential(
        user,
        EmailAuthProvider.credential(user.email, current),
      );
      await updatePassword(user, next);
      await updateDoc(doc(db, "users", user.uid), {
        mustChangePassword: false,
      });
      // AuthProvider's users-doc subscription picks up the cleared flag and
      // unblocks the portal automatically — nothing to navigate.
    } catch (err) {
      const code = err instanceof FirebaseError ? err.code : "";
      setError(
        code === "auth/invalid-credential" || code === "auth/wrong-password"
          ? "The temporary password is incorrect."
          : code === "auth/too-many-requests"
            ? "Too many attempts — wait a few minutes and try again."
            : "Couldn't update the password. Please try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg px-4">
      <div className="w-full max-w-[420px]">
        <Wordmark className="text-[24px]" />
        <h1 className="mt-6 font-display text-2xl font-black tracking-tight text-ink-900">
          Choose a new password
        </h1>
        <p className="mt-1 text-sm leading-relaxed text-ink-500">
          You signed in with a temporary password
          {fbUser?.email ? (
            <>
              {" "}
              for <strong>{fbUser.email}</strong>
            </>
          ) : null}
          . Set your own password to continue.
        </p>

        <form onSubmit={onSubmit} className="mt-8 space-y-4" noValidate>
          <Input
            label="Temporary password"
            type="password"
            autoComplete="current-password"
            value={current}
            onChange={(e) => setCurrent(e.target.value)}
            required
          />
          <Input
            label="New password"
            type="password"
            autoComplete="new-password"
            hint="At least 8 characters, with a letter and a number."
            value={next}
            onChange={(e) => setNext(e.target.value)}
            required
          />
          <Input
            label="Confirm new password"
            type="password"
            autoComplete="new-password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            required
          />

          {error && (
            <div
              role="alert"
              className="rounded-(--radius-input) border border-danger/25 bg-danger-soft px-4 py-3 text-[13px] font-semibold text-danger"
            >
              {error}
            </div>
          )}

          <Button type="submit" size="lg" loading={busy} className="w-full">
            Set new password
          </Button>
        </form>

        <button
          onClick={() => void signOutPortal()}
          className="mt-6 cursor-pointer text-[13px] font-semibold text-ink-500 hover:text-danger transition-colors"
        >
          Sign out instead
        </button>
      </div>
    </div>
  );
}
