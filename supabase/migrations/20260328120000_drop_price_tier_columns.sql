-- Remove the discovery tier columns that are no longer used by the app.
alter table public.vendor_profiles
  drop column if exists price_tier,
  drop column if exists price_tier_override;
