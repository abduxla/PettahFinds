"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { sendPasswordResetEmail } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    try {
      await sendPasswordResetEmail(auth, email.trim());
    } catch {
      // Deliberately swallowed: revealing whether an email exists would be
      // an account-enumeration vector. The success copy below is truthful
      // either way ("if an account exists…").
    }
    setSent(true);
    setSubmitting(false);
  }

  if (sent) {
    return (
      <div>
        <h2 className="font-display text-2xl font-black tracking-tight text-ink-900">
          Check your inbox
        </h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-500">
          If an account exists for <strong>{email}</strong>, a password reset
          link is on its way. The link expires after a short time — check your
          spam folder if you don&apos;t see it.
        </p>
        <Link href="/sign-in">
          <Button variant="secondary" className="mt-6 w-full">
            Back to sign in
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div>
      <h2 className="font-display text-2xl font-black tracking-tight text-ink-900">
        Reset password
      </h2>
      <p className="mt-1 text-sm text-ink-500">
        Enter your account email and we&apos;ll send you a reset link.
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
        <Button type="submit" size="lg" loading={submitting} className="w-full">
          Send reset link
        </Button>
      </form>

      <p className="mt-6 text-center">
        <Link
          href="/sign-in"
          className="text-[13px] font-semibold text-teal hover:text-teal-dark transition-colors"
        >
          ← Back to sign in
        </Link>
      </p>
    </div>
  );
}
