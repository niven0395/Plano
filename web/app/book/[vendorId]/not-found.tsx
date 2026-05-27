import Link from "next/link";
import { APP_STORE_URL } from "@/lib/env";

export default function VendorNotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 py-20 text-center">
      <h1 className="text-[28px] font-semibold leading-tight tracking-native-title text-ink dark:text-white">
        Link not found
      </h1>
      <p className="mt-4 max-w-sm text-[15px] leading-relaxed text-ink-muted dark:text-white/70">
        This booking link looks invalid or has expired. Ask the vendor to resend it.
      </p>
      <Link
        href={APP_STORE_URL}
        className="mt-10 inline-flex h-[52px] items-center justify-center rounded-button bg-accent px-7 text-[16px] font-semibold text-accent-on shadow-button transition active:scale-[0.98] hover:opacity-95"
      >
        Get Plano
      </Link>
    </main>
  );
}
