-- Drop the old 5-parameter overload of submit_booking_request_v2.
-- The 11-parameter version from 20260318120000_booking_hardening.sql
-- is the only one that should exist.
drop function if exists public.submit_booking_request_v2(uuid, uuid, date, text, uuid);
