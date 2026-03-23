-- Batch 3: Full-text search infrastructure for vendor discovery

-- Add generated tsvector column for full-text search
ALTER TABLE public.vendor_profiles
  ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(business_name, '') || ' ' ||
      coalesce(bio, '') || ' ' ||
      coalesce(style_summary, '') || ' ' ||
      coalesce(city, '') || ' ' ||
      coalesce(service_area, '') || ' ' ||
      coalesce(category, '') || ' ' ||
      coalesce(custom_category_name, '')
    )
  ) STORED;

-- GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_vendor_profiles_search
  ON public.vendor_profiles USING GIN(search_vector);
