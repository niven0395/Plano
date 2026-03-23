-- =============================================================================
-- Phase 1C: Supabase Queue for push notification delivery
-- Uses pgmq to create a durable job queue for async push notifications.
-- =============================================================================

-- Enable the pgmq extension (Supabase includes it but it must be activated)
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create the push notification job queue.
-- Each message contains a JSON payload with:
--   conversation_id, sender_role, message_body, recipient_id, sender_display_name
SELECT pgmq.create('push_notification_jobs');

-- Convenience wrapper so edge functions can enqueue via RPC.
-- Accepts the queue name and a JSONB payload, returns the message id.
CREATE OR REPLACE FUNCTION public.pgmq_send(
  queue_name text,
  msg jsonb
)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT pgmq.send(queue_name, msg);
$$;

-- Convenience wrapper to read messages from a queue via RPC.
-- vt = visibility timeout in seconds (how long the message is hidden from other readers).
-- qty = max number of messages to read.
CREATE OR REPLACE FUNCTION public.pgmq_read(
  queue_name text,
  vt integer DEFAULT 30,
  qty integer DEFAULT 10
)
RETURNS SETOF pgmq.message_record
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT * FROM pgmq.read(queue_name, vt, qty);
$$;

-- Convenience wrapper to archive a processed message.
CREATE OR REPLACE FUNCTION public.pgmq_archive(
  queue_name text,
  msg_id bigint
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT pgmq.archive(queue_name, msg_id);
$$;
