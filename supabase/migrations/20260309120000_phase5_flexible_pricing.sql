alter table public.vendor_profiles
  add column if not exists pricing_model text not null default 'starting_from',
  add column if not exists base_price_cents integer,
  add column if not exists hourly_rate_cents integer,
  add column if not exists minimum_hours integer,
  add column if not exists per_person_price_cents integer,
  add column if not exists minimum_guests integer,
  add column if not exists price_tier_override text;

alter table public.vendor_profiles
  drop constraint if exists vendor_profiles_base_price_cents_check,
  drop constraint if exists vendor_profiles_hourly_rate_cents_check,
  drop constraint if exists vendor_profiles_minimum_hours_check,
  drop constraint if exists vendor_profiles_per_person_price_cents_check,
  drop constraint if exists vendor_profiles_minimum_guests_check;

alter table public.vendor_profiles
  add constraint vendor_profiles_base_price_cents_check
    check (base_price_cents is null or base_price_cents >= 0),
  add constraint vendor_profiles_hourly_rate_cents_check
    check (hourly_rate_cents is null or hourly_rate_cents >= 0),
  add constraint vendor_profiles_minimum_hours_check
    check (minimum_hours is null or minimum_hours >= 1),
  add constraint vendor_profiles_per_person_price_cents_check
    check (per_person_price_cents is null or per_person_price_cents >= 0),
  add constraint vendor_profiles_minimum_guests_check
    check (minimum_guests is null or minimum_guests >= 1);

create index if not exists vendor_profiles_base_price_cents_idx
  on public.vendor_profiles (base_price_cents);

create table if not exists public.vendor_service_items (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  title text not null,
  price_cents integer not null check (price_cents >= 0),
  description text,
  display_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists vendor_service_items_vendor_id_order_idx
  on public.vendor_service_items (vendor_id, display_order);

alter table public.vendor_service_items enable row level security;

update public.vendor_profiles
set pricing_model = 'starting_from'
where price_tier is not null
   or starting_price is not null;

drop policy if exists "Anyone can read vendor service items" on public.vendor_service_items;
create policy "Anyone can read vendor service items"
on public.vendor_service_items
for select
using (true);

drop policy if exists "Owners can insert own vendor service items" on public.vendor_service_items;
create policy "Owners can insert own vendor service items"
on public.vendor_service_items
for insert
with check (vendor_id = auth.uid());

drop policy if exists "Owners can update own vendor service items" on public.vendor_service_items;
create policy "Owners can update own vendor service items"
on public.vendor_service_items
for update
using (vendor_id = auth.uid())
with check (vendor_id = auth.uid());

drop policy if exists "Owners can delete own vendor service items" on public.vendor_service_items;
create policy "Owners can delete own vendor service items"
on public.vendor_service_items
for delete
using (vendor_id = auth.uid());
