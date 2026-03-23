-- Fix message timestamp serialisation in server functions.
-- PostgreSQL serialises timestamptz inside jsonb_build_object with fractional
-- seconds (e.g. 2026-03-15T12:34:56.123456+00:00).  Swift's .iso8601
-- JSONDecoder date strategy does NOT handle fractional seconds, causing
-- decoding failures on both host and vendor message sends.
--
-- Fix: explicitly format created_at as ISO 8601 with milliseconds and Z suffix
-- so that any standard ISO 8601 parser (including Swift's) can decode it.

--------------------------------------------------------------------------------
-- 1. send_message_server – format created_at in the return JSONB
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_message_server(
  p_conversation_id uuid,
  p_sender_id uuid,
  p_body text,
  p_kind text DEFAULT 'text',
  p_client_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation conversations%ROWTYPE;
  v_sender_role text;
  v_msg messages%ROWTYPE;
BEGIN
  -- 1. Validate sender is a participant (lock row to prevent races)
  SELECT * INTO v_conversation
  FROM conversations
  WHERE id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found';
  END IF;

  IF v_conversation.host_id = p_sender_id THEN
    v_sender_role := 'host';
  ELSIF v_conversation.vendor_id = p_sender_id THEN
    v_sender_role := 'vendor';
  ELSE
    RAISE EXCEPTION 'Only a conversation participant can send messages';
  END IF;

  -- 2. Rate limit check
  IF NOT check_message_rate_limit(p_sender_id, 60, 30) THEN
    RAISE EXCEPTION 'Message rate limit exceeded';
  END IF;

  -- 3. Validate body length
  IF length(p_body) > 5000 THEN
    RAISE EXCEPTION 'Message body exceeds maximum length of 5000 characters';
  END IF;

  -- 4. Insert with client_id dedup
  IF p_client_id IS NOT NULL THEN
    INSERT INTO messages (conversation_id, sender_role, body, kind, client_id, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, p_client_id, 'sent')
    ON CONFLICT (client_id) DO NOTHING;

    SELECT * INTO v_msg
    FROM messages
    WHERE client_id = p_client_id;
  ELSE
    INSERT INTO messages (conversation_id, sender_role, body, kind, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, 'sent')
    RETURNING * INTO v_msg;
  END IF;

  -- 5. Return the message record as JSONB (explicit ISO 8601 timestamp)
  RETURN jsonb_build_object(
    'id', v_msg.id,
    'conversation_id', v_msg.conversation_id,
    'sender_role', v_msg.sender_role,
    'body', v_msg.body,
    'kind', v_msg.kind,
    'created_at', to_char(v_msg.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'status', v_msg.status,
    'client_id', v_msg.client_id
  );
END;
$$;

--------------------------------------------------------------------------------
-- 2. send_message_with_attachment_server – format both timestamps
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_message_with_attachment_server(
  p_conversation_id uuid,
  p_sender_id uuid,
  p_body text,
  p_kind text DEFAULT 'attachment',
  p_client_id uuid DEFAULT NULL,
  p_storage_path text DEFAULT NULL,
  p_file_name text DEFAULT NULL,
  p_mime_type text DEFAULT NULL,
  p_file_size_bytes bigint DEFAULT NULL,
  p_width integer DEFAULT NULL,
  p_height integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation conversations%ROWTYPE;
  v_sender_role text;
  v_msg messages%ROWTYPE;
  v_attachment message_attachments%ROWTYPE;
BEGIN
  -- 1. Validate sender is a participant (lock row to prevent races)
  SELECT * INTO v_conversation
  FROM conversations
  WHERE id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found';
  END IF;

  IF v_conversation.host_id = p_sender_id THEN
    v_sender_role := 'host';
  ELSIF v_conversation.vendor_id = p_sender_id THEN
    v_sender_role := 'vendor';
  ELSE
    RAISE EXCEPTION 'Only a conversation participant can send messages';
  END IF;

  -- 2. Rate limit check
  IF NOT check_message_rate_limit(p_sender_id, 60, 30) THEN
    RAISE EXCEPTION 'Message rate limit exceeded';
  END IF;

  -- 3. Validate body length
  IF length(p_body) > 5000 THEN
    RAISE EXCEPTION 'Message body exceeds maximum length of 5000 characters';
  END IF;

  -- 4. Validate attachment params
  IF p_storage_path IS NULL OR p_file_name IS NULL OR p_mime_type IS NULL OR p_file_size_bytes IS NULL THEN
    RAISE EXCEPTION 'Attachment requires storage_path, file_name, mime_type, and file_size_bytes';
  END IF;

  -- 5. Insert message with client_id dedup
  IF p_client_id IS NOT NULL THEN
    INSERT INTO messages (conversation_id, sender_role, body, kind, client_id, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, p_client_id, 'sent')
    ON CONFLICT (client_id) DO NOTHING;

    SELECT * INTO v_msg
    FROM messages
    WHERE client_id = p_client_id;
  ELSE
    INSERT INTO messages (conversation_id, sender_role, body, kind, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, 'sent')
    RETURNING * INTO v_msg;
  END IF;

  -- 6. Insert attachment (skip if already exists for this message, e.g. dedup replay)
  INSERT INTO message_attachments (message_id, storage_path, file_name, mime_type, file_size_bytes, width, height)
  VALUES (v_msg.id, p_storage_path, p_file_name, p_mime_type, p_file_size_bytes, p_width, p_height)
  ON CONFLICT DO NOTHING
  RETURNING * INTO v_attachment;

  -- If dedup replay, fetch existing attachment
  IF v_attachment.id IS NULL THEN
    SELECT * INTO v_attachment
    FROM message_attachments
    WHERE message_id = v_msg.id
    LIMIT 1;
  END IF;

  -- 7. Return message + attachment as JSONB (explicit ISO 8601 timestamps)
  RETURN jsonb_build_object(
    'message', jsonb_build_object(
      'id', v_msg.id,
      'conversation_id', v_msg.conversation_id,
      'sender_role', v_msg.sender_role,
      'body', v_msg.body,
      'kind', v_msg.kind,
      'created_at', to_char(v_msg.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'status', v_msg.status,
      'client_id', v_msg.client_id
    ),
    'attachment', jsonb_build_object(
      'id', v_attachment.id,
      'message_id', v_attachment.message_id,
      'storage_path', v_attachment.storage_path,
      'file_name', v_attachment.file_name,
      'mime_type', v_attachment.mime_type,
      'file_size_bytes', v_attachment.file_size_bytes,
      'width', v_attachment.width,
      'height', v_attachment.height,
      'created_at', to_char(v_attachment.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    )
  );
END;
$$;

--------------------------------------------------------------------------------
-- 3. Permissions (unchanged, re-stated for completeness)
--------------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.send_message_server(uuid, uuid, text, text, uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_message_server(uuid, uuid, text, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.send_message_with_attachment_server(uuid, uuid, text, text, uuid, text, text, text, bigint, integer, integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_message_with_attachment_server(uuid, uuid, text, text, uuid, text, text, text, bigint, integer, integer) TO service_role;
