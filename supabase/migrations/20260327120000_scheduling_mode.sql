-- Add scheduling_mode column to vendor_profiles
-- Replaces the boolean timeslots_enabled with a three-way enum:
--   calendar         (default) – host picks a date from a calendar
--   timeslots        – host picks a date + specific time slot
--   event_time_range – no calendar; host proposes date + time range, vendor reviews

alter table public.vendor_profiles
  add column if not exists scheduling_mode text not null default 'calendar';

alter table public.vendor_profiles
  add constraint vendor_profiles_scheduling_mode_check
    check (scheduling_mode in ('calendar', 'timeslots', 'event_time_range'));

-- Backfill existing timeslot vendors
update public.vendor_profiles
  set scheduling_mode = 'timeslots'
  where timeslots_enabled = true;
