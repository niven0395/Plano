-- Messaging reliability hardening:
-- 1. Rate limit only the current sender's authored messages.
-- 2. Restrict delivery receipts to the actual recipient.
-- 3. Seed inbox previews from the latest message.
-- 4. Add an atomic multi-attachment messaging RPC.

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
  FROM public.messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  WHERE m.sender_role != 'system'
    AND m.created_at > now() - (p_window_seconds || ' seconds')::interval
    AND (
      (c.host_id = p_user_id AND m.sender_role = 'host')
      OR
      (c.vendor_id = p_user_id AND m.sender_role = 'vendor')
    );

  RETURN v_count < p_max_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_message_delivered(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  UPDATE public.messages AS m
  SET status = 'delivered'
  FROM public.conversations AS c
  WHERE m.id = p_message_id
    AND c.id = m.conversation_id
    AND m.status = 'sent'
    AND m.sender_role != 'system'
    AND (
      (c.host_id = v_user_id AND m.sender_role = 'vendor')
      OR
      (c.vendor_id = v_user_id AND m.sender_role = 'host')
    );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_message_delivered(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_message_delivered(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fetch_booking_summaries(
  p_user_id uuid,
  p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF p_role NOT IN ('host', 'vendor') THEN
    RAISE EXCEPTION 'Role must be host or vendor.';
  END IF;

  SELECT coalesce(jsonb_agg(summary ORDER BY last_activity_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'conversation_id', c.id,
      'event_id', c.event_id,
      'vendor_id', c.vendor_id,
      'host_id', c.host_id,
      'host_display_name', c.host_display_name,
      'vendor_display_name', c.vendor_display_name,
      'vendor_category', c.vendor_category,
      'event_title', c.event_title,
      'event_date_label', c.event_date_label,
      'event_context_line', c.event_context_line,
      'stage', c.stage,
      'last_activity_at', c.last_activity_at,
      'host_unread_count', c.host_unread_count,
      'vendor_unread_count', c.vendor_unread_count,
      'latest_message_preview', coalesce(latest_message.preview, 'No messages yet.'),
      'latest_request_title', latest_request.title,
      'latest_request_budget_label', latest_request.budget_label,
      'latest_request_event_date', latest_request.event_date,
      'latest_booking_id', latest_booking.id,
      'latest_booking_stage', latest_booking.stage
    ) AS summary,
    c.last_activity_at
    FROM public.conversations c
    LEFT JOIN LATERAL (
      SELECT
        CASE
          WHEN m.kind = 'attachment' THEN
            CASE
              WHEN coalesce(attachment_count.count, 0) > 1 THEN
                'Sent ' || attachment_count.count || ' attachments'
              WHEN coalesce(attachment_count.count, 0) = 1 THEN
                'Sent 1 attachment'
              ELSE
                coalesce(nullif(trim(m.body), ''), 'Sent attachment')
            END
          ELSE coalesce(nullif(trim(m.body), ''), 'No messages yet.')
        END AS preview
      FROM public.messages m
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS count
        FROM public.message_attachments ma
        WHERE ma.message_id = m.id
      ) AS attachment_count ON true
      WHERE m.conversation_id = c.id
      ORDER BY m.sequence_number DESC, m.created_at DESC, m.id DESC
      LIMIT 1
    ) AS latest_message ON true
    LEFT JOIN LATERAL (
      SELECT br.title, br.budget_label, br.event_date
      FROM public.booking_requests br
      WHERE br.conversation_id = c.id
      ORDER BY br.created_at DESC
      LIMIT 1
    ) AS latest_request ON true
    LEFT JOIN LATERAL (
      SELECT b.id, b.stage
      FROM public.bookings b
      WHERE b.conversation_id = c.id
      ORDER BY b.updated_at DESC NULLS LAST, b.created_at DESC NULLS LAST
      LIMIT 1
    ) AS latest_booking ON true
    WHERE
      CASE
        WHEN p_role = 'host' THEN c.host_id = p_user_id
        WHEN p_role = 'vendor' THEN c.vendor_id = p_user_id
      END
  ) AS sub;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_message_with_attachments_server(
  p_conversation_id uuid,
  p_sender_id uuid,
  p_body text,
  p_kind text DEFAULT 'attachment',
  p_client_id uuid DEFAULT NULL,
  p_attachments jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations%ROWTYPE;
  v_sender_role text;
  v_msg public.messages%ROWTYPE;
  v_existing_attachments jsonb := '[]'::jsonb;
  v_attachment_json jsonb;
  v_attachment public.message_attachments%ROWTYPE;
  v_attachments jsonb := '[]'::jsonb;
BEGIN
  SELECT * INTO v_conversation
  FROM public.conversations
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

  IF jsonb_typeof(p_attachments) IS DISTINCT FROM 'array' OR jsonb_array_length(p_attachments) = 0 THEN
    RAISE EXCEPTION 'Attachments are required';
  END IF;

  IF jsonb_array_length(p_attachments) > 5 THEN
    RAISE EXCEPTION 'A maximum of 5 attachments is supported per message';
  END IF;

  IF p_client_id IS NOT NULL THEN
    INSERT INTO public.messages (conversation_id, sender_role, body, kind, client_id, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, p_client_id, 'sent')
    ON CONFLICT (client_id) WHERE client_id IS NOT NULL DO NOTHING;

    SELECT * INTO v_msg
    FROM public.messages
    WHERE client_id = p_client_id;
  ELSE
    INSERT INTO public.messages (conversation_id, sender_role, body, kind, status)
    VALUES (p_conversation_id, v_sender_role, p_body, p_kind, 'sent')
    RETURNING * INTO v_msg;
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ma.id,
        'message_id', ma.message_id,
        'storage_path', ma.storage_path,
        'file_name', ma.file_name,
        'mime_type', ma.mime_type,
        'file_size_bytes', ma.file_size_bytes,
        'width', ma.width,
        'height', ma.height,
        'thumbnail_path', ma.thumbnail_path,
        'created_at', ma.created_at
      )
      ORDER BY ma.created_at
    ),
    '[]'::jsonb
  )
  INTO v_existing_attachments
  FROM public.message_attachments ma
  WHERE ma.message_id = v_msg.id;

  IF jsonb_array_length(v_existing_attachments) > 0 THEN
    RETURN jsonb_build_object(
      'message', jsonb_build_object(
        'id', v_msg.id,
        'conversation_id', v_msg.conversation_id,
        'sender_role', v_msg.sender_role,
        'body', v_msg.body,
        'kind', v_msg.kind,
        'created_at', v_msg.created_at,
        'status', v_msg.status,
        'client_id', v_msg.client_id,
        'sequence_number', v_msg.sequence_number
      ),
      'attachments', v_existing_attachments
    );
  END IF;

  FOR v_attachment_json IN
    SELECT value
    FROM jsonb_array_elements(p_attachments)
  LOOP
    IF v_attachment_json ->> 'storage_path' IS NULL
      OR v_attachment_json ->> 'file_name' IS NULL
      OR v_attachment_json ->> 'mime_type' IS NULL
      OR v_attachment_json ->> 'file_size_bytes' IS NULL THEN
      RAISE EXCEPTION 'Each attachment requires storage_path, file_name, mime_type, and file_size_bytes';
    END IF;

    INSERT INTO public.message_attachments (
      message_id,
      storage_path,
      file_name,
      mime_type,
      file_size_bytes,
      width,
      height
    )
    VALUES (
      v_msg.id,
      v_attachment_json ->> 'storage_path',
      v_attachment_json ->> 'file_name',
      v_attachment_json ->> 'mime_type',
      (v_attachment_json ->> 'file_size_bytes')::bigint,
      CASE WHEN v_attachment_json ? 'width' THEN (v_attachment_json ->> 'width')::integer ELSE NULL END,
      CASE WHEN v_attachment_json ? 'height' THEN (v_attachment_json ->> 'height')::integer ELSE NULL END
    )
    RETURNING * INTO v_attachment;

    v_attachments := v_attachments || jsonb_build_array(
      jsonb_build_object(
        'id', v_attachment.id,
        'message_id', v_attachment.message_id,
        'storage_path', v_attachment.storage_path,
        'file_name', v_attachment.file_name,
        'mime_type', v_attachment.mime_type,
        'file_size_bytes', v_attachment.file_size_bytes,
        'width', v_attachment.width,
        'height', v_attachment.height,
        'thumbnail_path', v_attachment.thumbnail_path,
        'created_at', v_attachment.created_at
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'message', jsonb_build_object(
      'id', v_msg.id,
      'conversation_id', v_msg.conversation_id,
      'sender_role', v_msg.sender_role,
      'body', v_msg.body,
      'kind', v_msg.kind,
      'created_at', v_msg.created_at,
      'status', v_msg.status,
      'client_id', v_msg.client_id,
      'sequence_number', v_msg.sequence_number
    ),
    'attachments', v_attachments
  );
END;
$$;

REVOKE ALL ON FUNCTION public.send_message_with_attachments_server(uuid, uuid, text, text, uuid, jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.send_message_with_attachments_server(uuid, uuid, text, text, uuid, jsonb) TO authenticated, service_role;
