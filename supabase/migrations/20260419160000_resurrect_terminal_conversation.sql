-- Migration: Resurrect terminal conversations on host re-engagement.
--
-- When a host re-opens a vendor profile and starts a new conversation,
-- the SQL fast-path in `create_conversation_server` previously returned
-- the existing conversation row untouched. If that row's stage was
-- `cancelled` or `declined`, the inbox filter on the client treated it
-- as terminal and hid the new chat from every tab.
--
-- This migration extends the fast-path so that when an existing
-- conversation is in a terminal stage, we transition it back to `draft`
-- and bump `last_activity_at`. New stages (`requested`, `accepted`,
-- `paid`, etc.) are left untouched — only true terminal stages are
-- resurrected.

CREATE OR REPLACE FUNCTION public.create_conversation_server(
  p_host_id uuid,
  p_vendor_id uuid,
  p_event_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations%rowtype;
  v_vendor public.vendor_profiles%rowtype;
  v_host public.users%rowtype;
  v_event public.events%rowtype;
  v_conversation_id uuid;
  v_event_title text;
  v_event_date_label text;
  v_event_context_line text;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF NOT public.check_conversation_rate_limit(p_host_id, 3600, 10) THEN
    RAISE EXCEPTION 'Conversation rate limit exceeded. Please try again later.';
  END IF;

  -- Fast path: return existing conversation if found
  IF p_event_id IS NOT NULL THEN
    SELECT *
    INTO v_conversation
    FROM public.conversations
    WHERE host_id = p_host_id
      AND vendor_id = p_vendor_id
      AND event_id = p_event_id;
  ELSE
    SELECT *
    INTO v_conversation
    FROM public.conversations
    WHERE host_id = p_host_id
      AND vendor_id = p_vendor_id
      AND event_id IS NULL;
  END IF;

  IF FOUND THEN
    -- Resurrect terminal conversations so the host's re-engagement is
    -- visible in the inbox. Non-terminal stages (requested, accepted,
    -- paid, payment_requested, cancellation_requested) are preserved.
    IF v_conversation.stage IN ('cancelled', 'declined') THEN
      UPDATE public.conversations
      SET stage = 'draft',
          last_activity_at = v_now,
          updated_at = v_now
      WHERE id = v_conversation.id
      RETURNING * INTO v_conversation;
    END IF;
    RETURN row_to_json(v_conversation)::jsonb;
  END IF;

  -- Look up vendor profile
  SELECT *
  INTO v_vendor
  FROM public.vendor_profiles
  WHERE user_id = p_vendor_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vendor not found.';
  END IF;

  SELECT *
  INTO v_host
  FROM public.users
  WHERE id = p_host_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Host user not found.';
  END IF;

  IF p_event_id IS NOT NULL THEN
    SELECT *
    INTO v_event
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Event not found.';
    END IF;

    v_event_title := v_event.title;
    v_event_date_label := to_char(v_event.date AT TIME ZONE 'utc', 'Mon DD, YYYY');
    v_event_context_line := format('%s on %s', v_event.title, v_event_date_label);
  END IF;

  BEGIN
    INSERT INTO public.conversations (
      event_id,
      vendor_id,
      host_id,
      host_display_name,
      vendor_display_name,
      vendor_category,
      event_title,
      event_date_label,
      event_context_line,
      stage,
      last_activity_at,
      created_at,
      updated_at
    )
    VALUES (
      p_event_id,
      p_vendor_id,
      p_host_id,
      v_host.display_name,
      v_vendor.business_name,
      coalesce(v_vendor.category, 'General'),
      v_event_title,
      v_event_date_label,
      v_event_context_line,
      'draft',
      v_now,
      v_now,
      v_now
    )
    RETURNING * INTO v_conversation;
  EXCEPTION
    WHEN unique_violation THEN
      IF p_event_id IS NOT NULL THEN
        SELECT *
        INTO v_conversation
        FROM public.conversations
        WHERE host_id = p_host_id
          AND vendor_id = p_vendor_id
          AND event_id = p_event_id;
      ELSE
        SELECT *
        INTO v_conversation
        FROM public.conversations
        WHERE host_id = p_host_id
          AND vendor_id = p_vendor_id
          AND event_id IS NULL;
      END IF;

      IF v_conversation.stage IN ('cancelled', 'declined') THEN
        UPDATE public.conversations
        SET stage = 'draft',
            last_activity_at = v_now,
            updated_at = v_now
        WHERE id = v_conversation.id
        RETURNING * INTO v_conversation;
      END IF;
  END;

  RETURN row_to_json(v_conversation)::jsonb;
END;
$$;
