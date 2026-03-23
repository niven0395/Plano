create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text unique,
  display_name text not null,
  preferred_role text not null default 'host' check (preferred_role in ('host', 'vendor')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.host_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  display_name text not null,
  preferred_city text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vendor_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  business_name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.users (id) on delete cascade,
  title text not null,
  event_type text not null,
  date timestamptz not null,
  venue text not null,
  city text not null,
  guest_count text not null,
  budget_label text not null,
  planning_note text not null default '',
  progress double precision not null default 0.12 check (progress >= 0 and progress <= 1),
  stage text not null default 'requested',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists events_host_id_date_idx on public.events (host_id, date);

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists host_profiles_set_updated_at on public.host_profiles;
create trigger host_profiles_set_updated_at
before update on public.host_profiles
for each row execute function public.set_updated_at();

drop trigger if exists vendor_profiles_set_updated_at on public.vendor_profiles;
create trigger vendor_profiles_set_updated_at
before update on public.vendor_profiles
for each row execute function public.set_updated_at();

drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

alter table public.users enable row level security;
alter table public.host_profiles enable row level security;
alter table public.vendor_profiles enable row level security;
alter table public.events enable row level security;

drop policy if exists "Users can read own user row" on public.users;
create policy "Users can read own user row"
on public.users
for select
using (id = auth.uid());

drop policy if exists "Users can insert own user row" on public.users;
create policy "Users can insert own user row"
on public.users
for insert
with check (id = auth.uid());

drop policy if exists "Users can update own user row" on public.users;
create policy "Users can update own user row"
on public.users
for update
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "Users can read own host profile" on public.host_profiles;
create policy "Users can read own host profile"
on public.host_profiles
for select
using (user_id = auth.uid());

drop policy if exists "Users can insert own host profile" on public.host_profiles;
create policy "Users can insert own host profile"
on public.host_profiles
for insert
with check (user_id = auth.uid());

drop policy if exists "Users can update own host profile" on public.host_profiles;
create policy "Users can update own host profile"
on public.host_profiles
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can read own vendor profile" on public.vendor_profiles;
create policy "Users can read own vendor profile"
on public.vendor_profiles
for select
using (user_id = auth.uid());

drop policy if exists "Users can insert own vendor profile" on public.vendor_profiles;
create policy "Users can insert own vendor profile"
on public.vendor_profiles
for insert
with check (user_id = auth.uid());

drop policy if exists "Users can update own vendor profile" on public.vendor_profiles;
create policy "Users can update own vendor profile"
on public.vendor_profiles
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Hosts can read own events" on public.events;
create policy "Hosts can read own events"
on public.events
for select
using (host_id = auth.uid());

drop policy if exists "Hosts can insert own events" on public.events;
create policy "Hosts can insert own events"
on public.events
for insert
with check (host_id = auth.uid());

drop policy if exists "Hosts can update own events" on public.events;
create policy "Hosts can update own events"
on public.events
for update
using (host_id = auth.uid())
with check (host_id = auth.uid());

drop policy if exists "Hosts can delete own events" on public.events;
create policy "Hosts can delete own events"
on public.events
for delete
using (host_id = auth.uid());
