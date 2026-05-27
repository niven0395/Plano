import Image from "next/image";
import type { VendorSummary } from "@/lib/vendor";

export function VendorHero({ vendor }: { vendor: VendorSummary }) {
  return (
    <header className="flex flex-col items-center gap-4 text-center">
      {vendor.coverImageURL ? (
        <div className="relative h-48 w-full overflow-hidden rounded-card bg-surface-raised shadow-card sm:h-56">
          <Image
            src={vendor.coverImageURL}
            alt=""
            fill
            priority
            sizes="(max-width: 640px) 100vw, 560px"
            className="object-cover"
          />
        </div>
      ) : null}
      <div className="flex flex-col items-center gap-1.5 px-2">
        {vendor.category ? (
          <p className="text-[11px] font-medium uppercase tracking-[0.18em] text-ink-subtle dark:text-white/50">
            {vendor.category}
          </p>
        ) : null}
        <h1 className="text-[30px] font-semibold leading-tight tracking-native-title text-ink dark:text-white sm:text-[32px]">
          Book {vendor.businessName}
        </h1>
        <p className="max-w-sm text-[15px] text-ink-muted dark:text-white/70">
          Send a booking request — no account needed.
        </p>
      </div>
    </header>
  );
}
