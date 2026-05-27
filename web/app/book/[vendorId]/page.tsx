import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { SmartBanner } from "@/components/SmartBanner";
import { VendorHero } from "@/components/VendorHero";
import { fetchVendorSummary } from "@/lib/vendor";
import { BookingForm } from "./BookingForm";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ vendorId: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { vendorId } = await params;
  const vendor = await fetchVendorSummary(vendorId);
  if (!vendor) return { title: "Plano" };
  return {
    title: `Book ${vendor.businessName} · Plano`,
    description: `Send a booking request to ${vendor.businessName}.`,
    openGraph: {
      title: `Book ${vendor.businessName}`,
      description: "Send a booking request — no account needed.",
      images: vendor.coverImageURL ? [vendor.coverImageURL] : undefined,
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title: `Book ${vendor.businessName}`,
      description: "Send a booking request — no account needed.",
      images: vendor.coverImageURL ? [vendor.coverImageURL] : undefined,
    },
  };
}

export default async function BookVendorPage({ params }: PageProps) {
  const { vendorId } = await params;
  const vendor = await fetchVendorSummary(vendorId);
  if (!vendor) notFound();

  return (
    <main className="mx-auto w-full max-w-xl px-5 pb-12 pt-5 sm:px-6 sm:pt-10">
      <SmartBanner />
      <div className="mt-6 flex flex-col gap-8 sm:mt-10">
        <VendorHero vendor={vendor} />
        <section className="rounded-card border border-line bg-surface-card p-6 shadow-card dark:border-white/10 dark:bg-white/[0.04] sm:p-7">
          <BookingForm vendor={vendor} />
        </section>
      </div>
    </main>
  );
}
