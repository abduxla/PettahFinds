import { Wordmark } from "@/components/shell/brand";

/**
 * Auth chrome: brand panel on the left (desktop), form on the right.
 * Kept deliberately quiet — flat brand teal, no gradients.
 */
export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen">
      <aside className="hidden w-[44%] flex-col justify-between bg-teal-dark p-10 lg:flex">
        <Wordmark light className="text-[26px]" />
        <div>
          <h1 className="font-display text-3xl font-black leading-tight text-white">
            Business Membership
            <br />
            Portal
          </h1>
          <p className="mt-3 max-w-sm text-[15px] leading-relaxed text-white/70">
            Manage your PetaFinds membership, payments, invoices and support —
            all in one place.
          </p>
        </div>
        <p className="text-xs text-white/50">
          PetaFinds · Bringing Pettah online · Colombo 11
        </p>
      </aside>
      <main className="flex flex-1 items-center justify-center px-4 py-10">
        <div className="w-full max-w-[400px]">
          <div className="mb-8 lg:hidden">
            <Wordmark className="text-[24px]" />
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
