import Link from "next/link";
import { APP_STORE_URL } from "@/lib/env";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 py-16 text-center">
      <h1 className="text-2xl font-semibold tracking-tight">Page not found</h1>
      <p className="mt-3 text-sm text-ink-muted dark:text-white/70">
        The page you&apos;re looking for isn&apos;t here.
      </p>
      <Link
        href={APP_STORE_URL}
        className="mt-8 inline-flex items-center justify-center rounded-button bg-accent px-5 py-3 text-sm font-semibold text-accent-on"
      >
        Get Plano
      </Link>
    </main>
  );
}
