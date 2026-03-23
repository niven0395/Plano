-- Phase 4: Rate limiting and data retention infrastructure

-- 1. Rate limiting function for message sends
CREATE OR REPLACE FUNCTION public.check_message_rate_limit(
  p_user_id uuid,
  p_window_seconds integer DEFAULT 60,
  p_max_count integer DEFAULT 60
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM messages m
  JOIN conversations c ON c.id = m.conversation_id
  WHERE (c.host_id = p_user_id OR c.vendor_id = p_user_id)
    AND m.sender_role != 'system'
    AND m.created_at > now() - (p_window_seconds || ' seconds')::interval;

  RETURN v_count < p_max_count;
END;
$$;

-- 2. Rate limiting function for conversation creation
CREATE OR REPLACE FUNCTION public.check_conversation_rate_limit(
  p_user_id uuid,
  p_window_seconds integer DEFAULT 3600,
  p_max_count integer DEFAULT 10
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM conversations
  WHERE host_id = p_user_id
    AND created_at > now() - (p_window_seconds || ' seconds')::interval;

  RETURN v_count < p_max_count;
END;
$$;

-- 3. Data deletion requests for GDPR compliance
CREATE TABLE IF NOT EXISTS public.data_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  requested_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  metadata jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS data_deletion_requests_user_id_idx
  ON public.data_deletion_requests (user_id);
CREATE INDEX IF NOT EXISTS data_deletion_requests_status_idx
  ON public.data_deletion_requests (status) WHERE status = 'pending';

ALTER TABLE public.data_deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can request own data deletion"
  ON public.data_deletion_requests FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view own deletion requests"
  ON public.data_deletion_requests FOR SELECT
  USING (user_id = auth.uid());

-- 4. Server function to execute data deletion
CREATE OR REPLACE FUNCTION public.execute_data_deletion(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request data_deletion_requests%ROWTYPE;
  v_user_id uuid;
BEGIN
  SELECT * INTO v_request
  FROM data_deletion_requests
  WHERE id = p_request_id AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deletion request not found or already processed';
  END IF;

  v_user_id := v_request.user_id;

  UPDATE data_deletion_requests
  SET status = 'processing'
  WHERE id = p_request_id;

  -- Delete message reads
  DELETE FROM message_reads WHERE user_id = v_user_id;

  -- Delete device tokens
  DELETE FROM device_tokens WHERE user_id = v_user_id;

  -- Redact message content (keep structure for audit trail)
  UPDATE messages
  SET body = '[Message deleted]'
  WHERE conversation_id IN (
    SELECT id FROM conversations
    WHERE host_id = v_user_id OR vendor_id = v_user_id
  )
  AND sender_role IN (
    CASE WHEN EXISTS (SELECT 1 FROM conversations WHERE host_id = v_user_id) THEN 'host' ELSE NULL END,
    CASE WHEN EXISTS (SELECT 1 FROM conversations WHERE vendor_id = v_user_id) THEN 'vendor' ELSE NULL END
  );

  -- Delete attachment files (application should handle storage deletion separately)
  DELETE FROM message_attachments
  WHERE message_id IN (
    SELECT m.id FROM messages m
    JOIN conversations c ON c.id = m.conversation_id
    WHERE c.host_id = v_user_id OR c.vendor_id = v_user_id
  );

  UPDATE data_deletion_requests
  SET status = 'completed', completed_at = now()
  WHERE id = p_request_id;
END;
$$;
