"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { APP_STORE_URL } from "@/lib/env";

export function SmartBanner() {
  const [isIOS, setIsIOS] = useState(false);

  useEffect(() => {
    setIsIOS(/iPhone|iPad|iPod/.test(navigator.userAgent));
  }, []);

  if (!isIOS) return null;

  return (
    <div className="flex items-center justify-between gap-4 rounded-card border border-line bg-surface-raised px-5 py-3.5 text-[13px] text-ink-muted shadow-raised dark:border-white/10 dark:bg-white/[0.04] dark:text-white/70">
      <span>Open in the Plano app for the full experience.</span>
      <Link
        href={APP_STORE_URL}
        className="shrink-0 whitespace-nowrap text-[13px] font-semibold text-ink underline-offset-4 hover:underline dark:text-white"
      >
        Get app
      </Link>
    </div>
  );
}
