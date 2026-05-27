import type { NextConfig } from "next";
import path from "node:path";

const supabaseHostname = (() => {
  try {
    return new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://example.supabase.co").hostname;
  } catch {
    return "example.supabase.co";
  }
})();

const config: NextConfig = {
  reactStrictMode: true,
  turbopack: {
    root: path.resolve(__dirname),
  },
  images: {
    formats: ["image/avif", "image/webp"],
    remotePatterns: [
      {
        protocol: "https",
        hostname: supabaseHostname,
        pathname: "/storage/v1/object/**",
      },
    ],
  },
};

export default config;

import('@opennextjs/cloudflare').then(m => m.initOpenNextCloudflareForDev());
