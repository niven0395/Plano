alter table public.vendor_profiles
  add column if not exists collects_guest_count boolean not null default true;
