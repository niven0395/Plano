-- Phase 1A: Database Broadcast for message delivery
--
-- Replaces Postgres Changes (CDC) for new-message delivery with database
-- broadcast via realtime.send().  Each INSERT on the messages table fires a
-- trigger that broadcasts the new row to the conversation-specific topic
-- "messages:conv:<conversation_id>" with event "new_message".
--
-- Benefits over CDC:
--   - Clients subscribe only to their conversation topic instead of the
--     entire messages table, reducing fan-out and bandwidth.
--   - Payload shape is explicit and stable, decoupled from column ordering
--     or schema changes in the messages table.
--   - The trigger fires AFTER INSERT, so the row is already committed and
--     visible to readers by the time the broadcast arrives.

-- 1. Create the trigger function (SECURITY DEFINER so it can call realtime.send)
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
  -- Build payload matching the MessageRecord Swift DTO
  v_payload := jsonb_build_object(
    'id',              NEW.id,
    'conversation_id', NEW.conversation_id,
    'sender_role',     NEW.sender_role,
    'body',            NEW.body,
    'kind',            NEW.kind,
    'created_at',      to_char(NEW.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'status',          NEW.status,
    'client_id',       NEW.client_id
  );

  -- Topic scoped to the conversation
  v_topic := 'messages:conv:' || NEW.conversation_id::text;

  -- Broadcast via Supabase Realtime (private = true requires auth)
  PERFORM realtime.send(
    v_payload,
    'new_message',
    v_topic,
    true
  );

  RETURN NEW;
END;
$$;

-- 2. Create the AFTER INSERT trigger on messages
DROP TRIGGER IF EXISTS trg_broadcast_new_message ON public.messages;

CREATE TRIGGER trg_broadcast_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.broadcast_new_message();
