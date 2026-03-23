-- Fix send-message dedup inserts to target the existing partial unique index on
-- messages.client_id. ON CONFLICT (client_id) is not valid against a partial
-- unique index, which caused send-message edge calls to fail with HTTP 400.

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

  IF NOT check_message_rate_limit(p_sender_id, 60, 30) THEN
    RAISE EXCEPTION 'Message rate limit exceeded';
  END IF;

  IF length(p_body) > 5000 THEN
    RAISE EXCEPTION 'Message body exceeds maximum length of 5000 characters';
  END IF;

  IF p_client_id IS NOT NULL THEN
    INSERT INTO messages (conversation_id, sender_role, body, kind, client_id, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, p_client_id, 'sent')
    ON CONFLICT (client_id) WHERE client_id IS NOT NULL DO NOTHING;

    SELECT * INTO v_msg
    FROM messages
    WHERE client_id = p_client_id;
  ELSE
    INSERT INTO messages (conversation_id, sender_role, body, kind, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, 'sent')
    RETURNING * INTO v_msg;
  END IF;

  RETURN jsonb_build_object(
    'id', v_msg.id,
    'conversation_id', v_msg.conversation_id,
    'sender_role', v_msg.sender_role,
    'body', v_msg.body,
    'kind', v_msg.kind,
    'created_at', v_msg.created_at,
    'status', v_msg.status,
    'client_id', v_msg.client_id
  );
END;
$$;

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

  IF NOT check_message_rate_limit(p_sender_id, 60, 30) THEN
    RAISE EXCEPTION 'Message rate limit exceeded';
  END IF;

  IF length(p_body) > 5000 THEN
    RAISE EXCEPTION 'Message body exceeds maximum length of 5000 characters';
  END IF;

  IF p_storage_path IS NULL OR p_file_name IS NULL OR p_mime_type IS NULL OR p_file_size_bytes IS NULL THEN
    RAISE EXCEPTION 'Attachment requires storage_path, file_name, mime_type, and file_size_bytes';
  END IF;

  IF p_client_id IS NOT NULL THEN
    INSERT INTO messages (conversation_id, sender_role, body, kind, client_id, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, p_client_id, 'sent')
    ON CONFLICT (client_id) WHERE client_id IS NOT NULL DO NOTHING;

    SELECT * INTO v_msg
    FROM messages
    WHERE client_id = p_client_id;
  ELSE
    INSERT INTO messages (conversation_id, sender_role, body, kind, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, 'sent')
    RETURNING * INTO v_msg;
  END IF;

  INSERT INTO message_attachments (message_id, storage_path, file_name, mime_type, file_size_bytes, width, height)
  VALUES (v_msg.id, p_storage_path, p_file_name, p_mime_type, p_file_size_bytes, p_width, p_height)
  ON CONFLICT DO NOTHING
  RETURNING * INTO v_attachment;

  IF v_attachment.id IS NULL THEN
    SELECT * INTO v_attachment
    FROM message_attachments
    WHERE message_id = v_msg.id
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'message', jsonb_build_object(
      'id', v_msg.id,
      'conversation_id', v_msg.conversation_id,
      'sender_role', v_msg.sender_role,
      'body', v_msg.body,
      'kind', v_msg.kind,
      'created_at', v_msg.created_at,
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
      'created_at', v_attachment.created_at
    )
  );
END;
$$;
