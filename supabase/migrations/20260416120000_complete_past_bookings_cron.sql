-- Schedule daily auto-completion of paid bookings whose event date has passed.
--
-- The RPC public.complete_past_bookings() was introduced in
-- 20260412120000_booking_hardening.sql but no cron job was ever scheduled to
-- invoke it. Without this schedule, bookings remain in stage 'paid' indefinitely
-- after the event, and the '.completed' stage is unreachable in practice.
--
-- pattern mirrors the auto-resolve cancellation job in
-- 20260324120000_cancellation_v3.sql (wraps in pg_extension existence check so
-- local dev without pg_cron remains a no-op).

do $outer$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'complete-past-bookings',
      '0 2 * * *',
      'select public.complete_past_bookings()'
    );
  end if;
end;
$outer$;
