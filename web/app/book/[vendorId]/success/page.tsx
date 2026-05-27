import type { Metadata } from "next";
import Link from "next/link";
import { fetchVendorSummary } from "@/lib/vendor";
import { APP_STORE_URL } from "@/lib/env";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Request sent · Plano",
};

interface PageProps {
  params: Promise<{ vendorId: string }>;
  searchParams: Promise<{ email?: string }>;
}

export default async function SuccessPage({ params, searchParams }: PageProps) {
  const [{ vendorId }, { email }] = await Promise.all([params, searchParams]);
  const vendor = await fetchVendorSummary(vendorId);
  const vendorName = vendor?.businessName ?? "the vendor";

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 py-20 text-center">
      <div
        aria-hidden="true"
        className="flex h-16 w-16 items-center justify-center rounded-pill bg-accent text-accent-on shadow-button"
      >
        <svg
          width="28"
          height="28"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M22 2 11 13" />
          <path d="m22 2-7 20-4-9-9-4 20-7Z" />
        </svg>
      </div>

      <h1 className="mt-7 text-[32px] font-semibold leading-tight tracking-native-title text-ink dark:text-white">
        Request sent
      </h1>

      <p className="mt-4 max-w-sm text-[15px] leading-relaxed text-ink-muted dark:text-white/70">
        {vendorName} will reply
        {email ? (
          <>
            {" "}
            to{" "}
            <span className="font-medium text-ink dark:text-white">{email}</span>
          </>
        ) : (
          " by email"
        )}
        . Install Plano to chat directly, review their quote, and confirm the booking
        without leaving the thread.
      </p>

      <Link
        href={APP_STORE_URL}
        className="mt-10 inline-flex h-[52px] items-center justify-center rounded-button bg-accent px-8 text-[16px] font-semibold text-accent-on shadow-button transition active:scale-[0.98] hover:opacity-95"
      >
        Install Plano
      </Link>

      <Link
        href={`/book/${vendorId}`}
        className="mt-5 text-[13px] font-medium text-ink-subtle underline-offset-4 hover:underline dark:text-white/50"
      >
        Send another request
      </Link>
    </main>
  );
}
