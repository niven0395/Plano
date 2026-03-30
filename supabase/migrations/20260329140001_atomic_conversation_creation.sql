-- Migration: Replace create_conversation_server with atomic upsert.
--
-- The previous implementation used SELECT-then-INSERT (TOCTOU race).
-- Two concurrent requests could both pass the SELECT check and both INSERT,
-- producing duplicate conversations when event_id IS NULL had no unique index.
--
-- Now with the unique indexes in place, this function:
--   1. Fast-path SELECT for existing conversation (most common case).
--   2. INSERT with EXCEPTION WHEN unique_violation fallback.
--   3. On unique_violation, re-SELECT to return the winner.
--
-- This is fully atomic: the unique index is the source of truth.

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
  -- Rate limit check
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

  -- Look up host user
  SELECT *
  INTO v_host
  FROM public.users
  WHERE id = p_host_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Host user not found.';
  END IF;

  -- Look up event if provided
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

  -- Atomic insert — unique index prevents duplicates
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
      -- Concurrent insert won the race — return the winner
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
  END;

  RETURN row_to_json(v_conversation)::jsonb;
END;
$$;
