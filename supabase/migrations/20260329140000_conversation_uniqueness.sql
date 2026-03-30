-- Migration: Enforce conversation uniqueness per (host, vendor, event) triple.
--
-- The existing partial unique index (conversations_event_vendor_host_unique_idx)
-- only covers rows where event_id IS NOT NULL.  Direct-inquiry conversations
-- (event_id IS NULL) had no uniqueness protection, allowing duplicate threads.
--
-- This migration:
--   1. Reparents messages from duplicate conversations to the earliest (survivor).
--   2. Reparents booking_requests from duplicates to the survivor.
--   3. Updates the survivor's last_activity_at to the max across merged rows.
--   4. Deletes the duplicate conversations (CASCADE cleans up remaining children).
--   5. Creates a unique index for event_id IS NULL conversations.

BEGIN;

-- 1. Identify the survivor (earliest created_at) for each (host, vendor, event) group
--    and reparent messages from duplicates.
WITH survivors AS (
  SELECT DISTINCT ON (host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'))
    id AS survivor_id, host_id, vendor_id, event_id
  FROM public.conversations
  ORDER BY host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'), created_at ASC
),
duplicates AS (
  SELECT c.id AS dup_id, s.survivor_id
  FROM public.conversations c
  JOIN survivors s
    ON c.host_id = s.host_id
    AND c.vendor_id = s.vendor_id
    AND c.event_id IS NOT DISTINCT FROM s.event_id
  WHERE c.id != s.survivor_id
)
UPDATE public.messages m
SET conversation_id = d.survivor_id
FROM duplicates d
WHERE m.conversation_id = d.dup_id;

-- 2. Reparent booking_requests from duplicates to the survivor.
WITH survivors AS (
  SELECT DISTINCT ON (host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'))
    id AS survivor_id, host_id, vendor_id, event_id
  FROM public.conversations
  ORDER BY host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'), created_at ASC
),
duplicates AS (
  SELECT c.id AS dup_id, s.survivor_id
  FROM public.conversations c
  JOIN survivors s
    ON c.host_id = s.host_id
    AND c.vendor_id = s.vendor_id
    AND c.event_id IS NOT DISTINCT FROM s.event_id
  WHERE c.id != s.survivor_id
)
UPDATE public.booking_requests br
SET conversation_id = d.survivor_id
FROM duplicates d
WHERE br.conversation_id = d.dup_id;

-- 3. Update survivor last_activity_at to the max across all merged conversations.
WITH survivors AS (
  SELECT DISTINCT ON (host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'))
    id AS survivor_id, host_id, vendor_id, event_id
  FROM public.conversations
  ORDER BY host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'), created_at ASC
),
latest AS (
  SELECT s.survivor_id, MAX(c.last_activity_at) AS max_at
  FROM survivors s
  JOIN public.conversations c
    ON c.host_id = s.host_id
    AND c.vendor_id = s.vendor_id
    AND c.event_id IS NOT DISTINCT FROM s.event_id
  GROUP BY s.survivor_id
)
UPDATE public.conversations c
SET last_activity_at = l.max_at
FROM latest l
WHERE c.id = l.survivor_id
  AND c.last_activity_at < l.max_at;

-- 4. Delete duplicate conversations (messages and booking_requests already reparented;
--    remaining children like bookings, vendor_notes, audit trail are cleaned up by CASCADE).
WITH survivors AS (
  SELECT DISTINCT ON (host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'))
    id AS survivor_id, host_id, vendor_id, event_id
  FROM public.conversations
  ORDER BY host_id, vendor_id, COALESCE(event_id, '00000000-0000-0000-0000-000000000000'), created_at ASC
)
DELETE FROM public.conversations c
USING survivors s
WHERE c.host_id = s.host_id
  AND c.vendor_id = s.vendor_id
  AND c.event_id IS NOT DISTINCT FROM s.event_id
  AND c.id != s.survivor_id;

-- 5. Add unique index for NULL event_id conversations (direct inquiries).
--    Combined with the existing conversations_event_vendor_host_unique_idx
--    (for non-NULL event_id), this covers all cases.
CREATE UNIQUE INDEX conversations_vendor_host_null_event_unique_idx
  ON public.conversations (vendor_id, host_id)
  WHERE event_id IS NULL;

COMMIT;
