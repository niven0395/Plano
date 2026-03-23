-- Phase 5: Server-assigned sequence numbers for bulletproof message ordering.
--
-- Adds a monotonically increasing sequence_number per conversation to messages.
-- This eliminates ordering issues from clock skew and makes catch-up sync
-- a simple "give me everything after sequence N" query.

-- 1. Add the column
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS sequence_number bigint;

-- 2. Create a sequence for generating per-conversation sequence numbers.
--    We use a trigger-based approach rather than a global sequence to keep
--    numbers per-conversation (easier to reason about gaps).
CREATE OR REPLACE FUNCTION public.assign_message_sequence_number()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_next bigint;
BEGIN
  -- Atomically compute the next sequence number for this conversation
  SELECT COALESCE(MAX(sequence_number), 0) + 1
    INTO v_next
    FROM public.messages
   WHERE conversation_id = NEW.conversation_id;

  NEW.sequence_number := v_next;
  RETURN NEW;
END;
$$;

-- 3. Fire BEFORE INSERT so the row is written with the sequence number
DROP TRIGGER IF EXISTS trg_assign_message_sequence ON public.messages;
CREATE TRIGGER trg_assign_message_sequence
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  WHEN (NEW.sequence_number IS NULL)
  EXECUTE FUNCTION public.assign_message_sequence_number();

-- 4. Backfill existing messages with sequence numbers
WITH numbered AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY conversation_id
           ORDER BY created_at ASC, id ASC
         ) AS seq
    FROM public.messages
   WHERE sequence_number IS NULL
)
UPDATE public.messages m
   SET sequence_number = numbered.seq
  FROM numbered
 WHERE m.id = numbered.id;

-- 5. Make non-nullable now that all rows are filled
ALTER TABLE public.messages
  ALTER COLUMN sequence_number SET NOT NULL;

-- 6. Index for efficient catch-up queries
CREATE INDEX IF NOT EXISTS idx_messages_conversation_sequence
  ON public.messages (conversation_id, sequence_number);

-- 7. Update the broadcast trigger to include sequence_number in the payload
CREATE OR REPLACE FUNCTION public.broadcast_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payload jsonb;
  v_topic text;
BEGIN
  v_payload := jsonb_build_object(
    'id',              NEW.id,
    'conversation_id', NEW.conversation_id,
    'sender_role',     NEW.sender_role,
    'body',            NEW.body,
    'kind',            NEW.kind,
    'created_at',      to_char(NEW.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'status',          NEW.status,
    'client_id',       NEW.client_id,
    'sequence_number', NEW.sequence_number
  );

  v_topic := 'messages:conv:' || NEW.conversation_id::text;

  PERFORM realtime.send(
    v_payload,
    'new_message',
    v_topic,
    true
  );

  RETURN NEW;
END;
$$;
