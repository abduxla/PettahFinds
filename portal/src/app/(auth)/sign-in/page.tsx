"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  browserLocalPersistence,
  browserSessionPersistence,
  setPersistence,
  signInWithEmailAndPassword,
} from "firebase/auth";
import { FirebaseError } from "firebase/app";
import { auth } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

/** Map Firebase Auth error codes to human copy (never leak raw codes). */
function friendlyAuthError(err: unknown): string {
  const code = err instanceof FirebaseError ? err.code : "";
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "Incorrect email or password. Please try again.";
    case "auth/invalid-email":
      return "That doesn't look like a valid email address.";
    case "auth/user-disabled":
      return "This account has been disabled. Contact PetaFinds support.";
    case "auth/too-many-requests":
      return "Too many failed attempts. Please wait a few minutes and try again.";
    case "auth/network-request-failed":
      return "Network error — check your connection and try again.";
    default:
      return "Sign-in failed. Please try again.";
  }
}

export default function SignInPage() {
  const router = useRouter();
  const { fbUser, loading } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Already signed in (e.g. back-navigation) → bounce to role home.
  useEffect(() => {
    if (!loading && fbUser) router.replace("/");
  }, [loading, fbUser, router]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      // "Remember me" = durable local persistence; otherwise the session
      // ends when the browser closes.
      await setPersistence(
        auth,
        remember ? browserLocalPersistence : browserSessionPersistence,
      );
      await signInWithEmailAndPassword(auth, email.trim(), password);
      router.replace("/");
    } catch (err) {
      setError(friendlyAuthError(err));
      setSubmitting(false);
    }
  }

  return (
    <div>
      <h2 className="font-display text-2xl font-black tracking-tight text-ink-900">
        Sign in
      </h2>
      <p className="mt-1 text-sm text-ink-500">
        Use your PetaFinds business account credentials.
      </p>

      <form onSubmit={onSubmit} className="mt-8 space-y-4" noValidate>
        <Input
          label="Email"
          type="email"
          autoComplete="email"
          placeholder="you@business.lk"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <Input
          label="Password"
          type="password"
          autoComplete="current-password"
          placeholder="••••••••"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />

        <div className="flex items-center justify-between pt-1">
          <label className="flex cursor-pointer items-center gap-2 text-[13px] font-semibold text-ink-700">
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
              className="size-4 accent-(--color-teal)"
            />
            Remember me
          </label>
          <Link
            href="/forgot-password"
            className="text-[13px] font-semibold text-teal hover:text-teal-dark transition-colors"
          >
            Forgot password?
          </Link>
        </div>

        {error && (
          <div
            role="alert"
            className="rounded-(--radius-input) border border-danger/25 bg-danger-soft px-4 py-3 text-[13px] font-semibold text-danger"
          >
            {error}
          </div>
        )}

        <Button
          type="submit"
          size="lg"
          loading={submitting}
          className="w-full"
        >
          Sign in
        </Button>
      </form>

      <p className="mt-8 text-center text-xs leading-relaxed text-ink-500">
        Business accounts are created when your PetaFinds registration is
        approved. Need help?{" "}
        <a
          href="mailto:support@petafinds.lk"
          className="font-semibold text-teal hover:text-teal-dark"
        >
          support@petafinds.lk
        </a>
      </p>
    </div>
  );
}
