import Link from "next/link";
import { APP_STORE_URL } from "@/lib/env";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col items-center justify-center px-6 py-20 text-center">
      <p className="text-[11px] font-medium uppercase tracking-[0.22em] text-ink-subtle dark:text-white/50">
        Plano
      </p>
      <h1 className="mt-5 text-[34px] font-semibold leading-tight tracking-native-title text-ink dark:text-white sm:text-[40px]">
        Party planning, without the guesswork.
      </h1>
      <p className="mt-5 max-w-md text-[15px] leading-relaxed text-ink-muted dark:text-white/70">
        Vendors share a link. You send a booking request in seconds. The iOS app is
        where you chat, review quotes, and confirm the booking.
      </p>
      <Link
        href={APP_STORE_URL}
        className="mt-10 inline-flex h-[52px] items-center justify-center rounded-button bg-accent px-7 text-[16px] font-semibold text-accent-on shadow-button transition active:scale-[0.98] hover:opacity-95"
      >
        Download Plano for iPhone
      </Link>
      <p className="mt-5 text-[12px] text-ink-subtle dark:text-white/50">
        Have a vendor link? Open it on your phone to start.
      </p>
    </main>
  );
}
