-- Phase 7A: Scheduled maintenance cron jobs
--
-- Uses pg_cron for periodic cleanup tasks:
-- 1. Prune old read receipts (>90 days)
-- 2. Retry sweep for stuck push notification queue items
-- 3. Clean up expired account deletion requests

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres role (required for scheduling)
GRANT USAGE ON SCHEMA cron TO postgres;

-- 1. Prune read receipts older than 90 days (daily at 3am UTC)
SELECT cron.schedule(
  'prune-old-read-receipts',
  '0 3 * * *',
  $$DELETE FROM public.message_reads WHERE created_at < NOW() - INTERVAL '90 days'$$
);

-- 2. Retry sweep for stuck push queue items (every 5 minutes)
-- Messages that have been read but not archived (read_ct > 0, still in queue)
-- are likely stuck. Re-enqueue them by resetting visibility.
SELECT cron.schedule(
  'push-queue-retry-sweep',
  '*/5 * * * *',
  $$SELECT pgmq.set_vt('push_notification_jobs', msg_id, 0)
    FROM pgmq.read('push_notification_jobs', 0, 100)
    WHERE read_ct > 3$$
);

-- 3. Clean up expired data deletion requests (daily at 4am UTC)
SELECT cron.schedule(
  'cleanup-expired-deletions',
  '0 4 * * *',
  $$DELETE FROM public.data_deletion_requests
    WHERE status = 'completed'
      AND completed_at < NOW() - INTERVAL '30 days'$$
);
