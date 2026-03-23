alter table public.vendor_profiles
  add column if not exists available_days integer[] not null default '{1,2,3,4,5,6,7}'::integer[],
  add column if not exists schedule_preset text not null default 'every_day',
  add column if not exists lead_time_days integer not null default 0,
  add column if not exists advance_booking_days integer not null default 180;

alter table public.vendor_profiles
  drop constraint if exists vendor_profiles_lead_time_check,
  drop constraint if exists vendor_profiles_advance_booking_check;

alter table public.vendor_profiles
  add constraint vendor_profiles_lead_time_check
  check (lead_time_days >= 0 and lead_time_days <= 90),
  add constraint vendor_profiles_advance_booking_check
  check (advance_booking_days >= 7 and advance_booking_days <= 365);
