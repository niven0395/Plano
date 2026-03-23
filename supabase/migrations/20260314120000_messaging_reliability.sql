-- Phase 1: Messaging reliability infrastructure
-- Adds delivery status, client-side dedup, read receipts, and server-side unread counts

-- 1. Add status column to messages for delivery state tracking
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'sent'
  CHECK (status IN ('sending', 'sent', 'delivered', 'read'));

-- 2. Add client_id for optimistic message reconciliation / deduplication
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS messages_client_id_idx
  ON public.messages (client_id) WHERE client_id IS NOT NULL;

-- 3. Add server-side unread counts to conversations
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS host_unread_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS vendor_unread_count integer NOT NULL DEFAULT 0;

-- 4. Message reads table for read receipts
CREATE TABLE IF NOT EXISTS public.message_reads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  read_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS message_reads_message_id_idx
  ON public.message_reads (message_id);
CREATE INDEX IF NOT EXISTS message_reads_user_id_idx
  ON public.message_reads (user_id);

ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read message reads"
  ON public.message_reads FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
      WHERE m.id = message_reads.message_id
        AND (c.host_id = auth.uid() OR c.vendor_id = auth.uid())
    )
  );

CREATE POLICY "Users can mark messages read"
  ON public.message_reads FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- 5. Server function: mark all messages in a conversation as read for a role
CREATE OR REPLACE FUNCTION public.mark_messages_read(
  p_conversation_id uuid,
  p_role text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_conversation conversations%ROWTYPE;
BEGIN
  -- Verify participant
  SELECT * INTO v_conversation
  FROM conversations
  WHERE id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found';
  END IF;

  IF p_role = 'host' AND v_conversation.host_id != v_user_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_role = 'vendor' AND v_conversation.vendor_id != v_user_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Batch insert read receipts for unread messages from counterpart
  INSERT INTO message_reads (message_id, user_id)
  SELECT m.id, v_user_id
  FROM messages m
  WHERE m.conversation_id = p_conversation_id
    AND m.sender_role != p_role
    AND m.sender_role != 'system'
    AND NOT EXISTS (
      SELECT 1 FROM message_reads mr
      WHERE mr.message_id = m.id AND mr.user_id = v_user_id
    )
  ON CONFLICT (message_id, user_id) DO NOTHING;

  -- Update delivery status of those messages to 'read'
  UPDATE messages
  SET status = 'read'
  WHERE conversation_id = p_conversation_id
    AND sender_role != p_role
    AND sender_role != 'system'
    AND status != 'read';

  -- Reset unread count for this role
  IF p_role = 'host' THEN
    UPDATE conversations SET host_unread_count = 0 WHERE id = p_conversation_id;
  ELSIF p_role = 'vendor' THEN
    UPDATE conversations SET vendor_unread_count = 0 WHERE id = p_conversation_id;
  END IF;
END;
$$;

-- 6. Server function: increment unread count after message insert
CREATE OR REPLACE FUNCTION public.increment_unread_on_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.sender_role = 'host' THEN
    UPDATE conversations
    SET vendor_unread_count = vendor_unread_count + 1,
        last_activity_at = NEW.created_at
    WHERE id = NEW.conversation_id;
  ELSIF NEW.sender_role = 'vendor' THEN
    UPDATE conversations
    SET host_unread_count = host_unread_count + 1,
        last_activity_at = NEW.created_at
    WHERE id = NEW.conversation_id;
  ELSIF NEW.sender_role = 'system' THEN
    UPDATE conversations
    SET last_activity_at = NEW.created_at
    WHERE id = NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER messages_increment_unread
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_unread_on_message();

-- 7. Enable Realtime for messages and conversations tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;

-- 8. Add message content constraints for security
ALTER TABLE public.messages
  ADD CONSTRAINT messages_body_max_length CHECK (length(body) <= 5000);
