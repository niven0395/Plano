-- Timeslot booking system: opt-in appointment-style scheduling for vendors
-- Adds timeslot config columns to vendor_profiles and a separate table for slot-level bookings.

-- 1. Add timeslot config columns to vendor_profiles
alter table public.vendor_profiles
  add column if not exists timeslots_enabled boolean not null default false,
  add column if not exists timeslot_duration_minutes integer not null default 60,
  add column if not exists timeslot_start_hour integer not null default 9,
  add column if not exists timeslot_start_minute integer not null default 0,
  add column if not exists timeslot_end_hour integer not null default 17,
  add column if not exists timeslot_end_minute integer not null default 0,
  add column if not exists timeslot_buffer_minutes integer not null default 0,
  add column if not exists timeslot_rolling_window_days integer not null default 14,
  add column if not exists timeslot_timezone text not null default 'America/New_York';

alter table public.vendor_profiles
  add constraint vendor_profiles_timeslot_duration_check
    check (timeslot_duration_minutes in (15, 30, 45, 60, 90, 120)),
  add constraint vendor_profiles_timeslot_hours_check
    check (timeslot_start_hour >= 0 and timeslot_start_hour <= 23
       and timeslot_end_hour >= 0 and timeslot_end_hour <= 23),
  add constraint vendor_profiles_timeslot_rolling_window_check
    check (timeslot_rolling_window_days >= 1 and timeslot_rolling_window_days <= 90);

-- 2. Create vendor_timeslot_bookings table
create table if not exists public.vendor_timeslot_bookings (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  date date not null,
  start_time time not null,
  end_time time not null,
  status text not null check (status in ('booked', 'blocked', 'hold')),
  booking_id uuid references public.bookings (id) on delete set null,
  conversation_id uuid references public.conversations (id) on delete set null,
  host_id uuid references public.users (id) on delete set null,
  note text,
  created_at timestamptz not null default timezone('utc', now()),

  unique (vendor_id, date, start_time)
);

create index on public.vendor_timeslot_bookings (vendor_id, date);
create index on public.vendor_timeslot_bookings (vendor_id, date, status);

-- 3. RLS policies for vendor_timeslot_bookings
alter table public.vendor_timeslot_bookings enable row level security;

create policy "Anyone can read timeslot bookings"
  on public.vendor_timeslot_bookings for select using (true);

create policy "Vendors can insert own timeslot bookings"
  on public.vendor_timeslot_bookings for insert
  with check (vendor_id = auth.uid());

create policy "Vendors can update own timeslot bookings"
  on public.vendor_timeslot_bookings for update
  using (vendor_id = auth.uid());

create policy "Vendors can delete own timeslot bookings"
  on public.vendor_timeslot_bookings for delete
  using (vendor_id = auth.uid());

-- 4. Add time columns to booking_requests
alter table public.booking_requests
  add column if not exists requested_time_start time,
  add column if not exists requested_time_end time;
