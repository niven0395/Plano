alter table public.vendor_profiles
  add column if not exists price_tier text;
