-- Schedule the external-booking email drainer to run every minute.
--
-- Sends pending guest-host booking emails via the send-external-booking-email
-- edge function. Prerequisite: the service role key must be set once as a
-- database GUC (via the Supabase SQL editor) so the cron job can authenticate:
--
--   alter database postgres set app.settings.service_role_key = '<key>';
--
-- Without that GUC, the cron still runs but the HTTP call returns 401 —
-- safe failure, no data corruption.
--
-- Pattern mirrors 20260416120000_complete_past_bookings_cron.sql (wraps in
-- pg_extension existence check so local dev without pg_cron / pg_net is a
-- no-op).

do $outer$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then

    -- Unschedule any prior registration so re-running this migration is
    -- idempotent.
    if exists (select 1 from cron.job where jobname = 'drain-external-email-jobs') then
      perform cron.unschedule('drain-external-email-jobs');
    end if;

    perform cron.schedule(
      'drain-external-email-jobs',
      '* * * * *',
      $cron$
        select net.http_post(
          url := 'https://uytbxijaigrvkxpcbohm.supabase.co/functions/v1/send-external-booking-email',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object('batch_size', 25)
        );
      $cron$
    );
  end if;
end;
$outer$;
