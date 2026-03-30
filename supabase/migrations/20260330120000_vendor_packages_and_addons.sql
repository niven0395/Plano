-- Vendor Packages table for tiered pricing (e.g. Essential / Standard / Premium)
CREATE TABLE IF NOT EXISTS public.vendor_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendor_profiles(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    description TEXT,
    included_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_highlighted BOOLEAN NOT NULL DEFAULT false,
    pricing_unit TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS vendor_packages_vendor_id_order_idx
    ON public.vendor_packages (vendor_id, display_order);

ALTER TABLE public.vendor_packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read vendor packages"
    ON public.vendor_packages FOR SELECT USING (true);

CREATE POLICY "Owners can insert own vendor packages"
    ON public.vendor_packages FOR INSERT WITH CHECK (vendor_id = auth.uid());

CREATE POLICY "Owners can update own vendor packages"
    ON public.vendor_packages FOR UPDATE
    USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid());

CREATE POLICY "Owners can delete own vendor packages"
    ON public.vendor_packages FOR DELETE USING (vendor_id = auth.uid());

-- Add item_type to vendor_service_items to distinguish services from add-ons
ALTER TABLE public.vendor_service_items
    ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'service';

-- Add pricing image URLs to vendor profiles
ALTER TABLE public.vendor_profiles
    ADD COLUMN IF NOT EXISTS pricing_image_urls TEXT[] NOT NULL DEFAULT '{}'::text[];
