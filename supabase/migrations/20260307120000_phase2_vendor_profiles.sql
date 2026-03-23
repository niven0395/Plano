alter table public.users
  add column if not exists anonymous_display_name text,
  add column if not exists contact_phone text,
  add column if not exists contact_email text;

alter table public.vendor_profiles
  add column if not exists category text,
  add column if not exists custom_category_name text,
  add column if not exists bio text,
  add column if not exists style_summary text,
  add column if not exists city text,
  add column if not exists service_area text,
  add column if not exists starting_price text,
  add column if not exists pricing_visibility text not null default 'public',
  add column if not exists availability_mode text not null default 'contact_to_discuss',
  add column if not exists booking_mode text not null default 'inquiry_only',
  add column if not exists payment_mode text not null default 'external',
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists instagram_handle text,
  add column if not exists tiktok_handle text,
  add column if not exists services text[] not null default '{}'::text[],
  add column if not exists profile_completeness integer not null default 10,
  add column if not exists tags text[] not null default '{}'::text[],
  add column if not exists onboarded_at timestamptz;

alter table public.vendor_profiles
  drop constraint if exists vendor_profiles_profile_completeness_check;

alter table public.vendor_profiles
  add constraint vendor_profiles_profile_completeness_check
  check (profile_completeness >= 0 and profile_completeness <= 100);

create index if not exists vendor_profiles_tags_idx
  on public.vendor_profiles
  using gin (tags);

create table if not exists public.vendor_gallery_images (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  storage_path text not null,
  display_order integer not null default 0,
  caption text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists vendor_gallery_images_vendor_id_order_idx
  on public.vendor_gallery_images (vendor_id, display_order);

alter table public.vendor_gallery_images enable row level security;

drop policy if exists "Anyone can read vendor profiles" on public.vendor_profiles;
create policy "Anyone can read vendor profiles"
on public.vendor_profiles
for select
using (true);

drop policy if exists "Owners can delete own vendor profile" on public.vendor_profiles;
create policy "Owners can delete own vendor profile"
on public.vendor_profiles
for delete
using (user_id = auth.uid());

drop policy if exists "Anyone can read vendor gallery images" on public.vendor_gallery_images;
create policy "Anyone can read vendor gallery images"
on public.vendor_gallery_images
for select
using (true);

drop policy if exists "Owners can insert own vendor gallery images" on public.vendor_gallery_images;
create policy "Owners can insert own vendor gallery images"
on public.vendor_gallery_images
for insert
with check (vendor_id = auth.uid());

drop policy if exists "Owners can update own vendor gallery images" on public.vendor_gallery_images;
create policy "Owners can update own vendor gallery images"
on public.vendor_gallery_images
for update
using (vendor_id = auth.uid())
with check (vendor_id = auth.uid());

drop policy if exists "Owners can delete own vendor gallery images" on public.vendor_gallery_images;
create policy "Owners can delete own vendor gallery images"
on public.vendor_gallery_images
for delete
using (vendor_id = auth.uid());
