create table if not exists public.saved_vendors (
  host_id uuid not null references public.users (id) on delete cascade,
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (host_id, vendor_id)
);

create index if not exists saved_vendors_host_id_created_at_idx
on public.saved_vendors (host_id, created_at desc);

create index if not exists saved_vendors_vendor_id_idx
on public.saved_vendors (vendor_id);

create index if not exists vendor_profiles_category_profile_completeness_idx
on public.vendor_profiles (category, profile_completeness desc, business_name);

create index if not exists vendor_profiles_onboarded_at_idx
on public.vendor_profiles (onboarded_at desc);

alter table public.saved_vendors enable row level security;

drop policy if exists "Hosts can read own saved vendors" on public.saved_vendors;
create policy "Hosts can read own saved vendors"
on public.saved_vendors
for select
using (host_id = auth.uid());

drop policy if exists "Hosts can insert own saved vendors" on public.saved_vendors;
create policy "Hosts can insert own saved vendors"
on public.saved_vendors
for insert
with check (host_id = auth.uid());

drop policy if exists "Hosts can delete own saved vendors" on public.saved_vendors;
create policy "Hosts can delete own saved vendors"
on public.saved_vendors
for delete
using (host_id = auth.uid());
