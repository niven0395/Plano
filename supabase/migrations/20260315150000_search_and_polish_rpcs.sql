-- Batch 3: Search, quote revision, conversation creation, and booking summary RPCs

--------------------------------------------------------------------------------
-- 1. search_vendors_server
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_vendors_server(
  p_query text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_event_date date DEFAULT NULL,
  p_price_min integer DEFAULT NULL,
  p_price_max integer DEFAULT NULL,
  p_limit integer DEFAULT 24,
  p_offset integer DEFAULT 0
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
  SELECT coalesce(jsonb_agg(row_result ORDER BY rank DESC, profile_completeness DESC, business_name), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      row_to_json(vp.*)::jsonb AS row_result,
      vp.profile_completeness,
      vp.business_name,
      CASE
        WHEN p_query IS NOT NULL AND btrim(p_query) <> ''
          THEN ts_rank(vp.search_vector, plainto_tsquery('english', p_query))
        ELSE 0
      END AS rank
    FROM public.vendor_profiles vp
    LEFT JOIN public.vendor_availability va
      ON va.vendor_id = vp.user_id
      AND va.date = p_event_date
      AND va.status IN ('booked', 'blocked')
    WHERE
      -- Text search filter
      (
        p_query IS NULL
        OR btrim(p_query) = ''
        OR vp.search_vector @@ plainto_tsquery('english', p_query)
      )
      -- Category filter
      AND (
        p_category IS NULL
        OR vp.category = p_category
      )
      -- City filter (partial, case-insensitive)
      AND (
        p_city IS NULL
        OR vp.city ILIKE '%' || p_city || '%'
      )
      -- Availability filter: exclude vendors booked/blocked on the requested date
      AND (
        p_event_date IS NULL
        OR va.id IS NULL
      )
      -- Only include vendors that have completed onboarding
      AND vp.onboarded_at IS NOT NULL
    ORDER BY rank DESC, vp.profile_completeness DESC, vp.business_name
    LIMIT p_limit
    OFFSET p_offset
  ) AS sub;

  RETURN v_result;
END;
$$;

--------------------------------------------------------------------------------
-- 2. revise_quote_server
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.revise_quote_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_previous_quote_id uuid,
  p_title text,
  p_total_amount_label text,
  p_deposit_amount_label text,
  p_total_amount_cents integer,
  p_deposit_amount_cents integer,
  p_expires_at timestamptz,
  p_turnaround_label text,
  p_included_items text[],
  p_note text,
  p_currency text DEFAULT 'usd',
  p_conflict_acknowledged boolean DEFAULT false,
  p_idempotency_key uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations%rowtype;
  v_previous_quote public.booking_quotes%rowtype;
  v_event_date date;
  v_booking_id uuid;
  v_quote_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_date_conflicts jsonb := '[]'::jsonb;
BEGIN
  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.booking_events
      WHERE idempotency_key = p_idempotency_key
    ) THEN
      RETURN public.booking_transition_snapshot(p_conversation_id);
    END IF;
  END IF;

  -- Validate amounts
  IF p_total_amount_cents IS NULL OR p_total_amount_cents <= 0 THEN
    RAISE EXCEPTION 'A positive total amount is required.';
  END IF;

  IF p_deposit_amount_cents IS NULL OR p_deposit_amount_cents <= 0 THEN
    RAISE EXCEPTION 'A positive deposit amount is required.';
  END IF;

  IF p_deposit_amount_cents > p_total_amount_cents THEN
    RAISE EXCEPTION 'Deposit cannot exceed the quote total.';
  END IF;

  IF p_expires_at IS NULL OR p_expires_at <= v_now THEN
    RAISE EXCEPTION 'Quote expiry must be in the future.';
  END IF;

  -- Lock conversation
  SELECT *
  INTO v_conversation
  FROM public.conversations
  WHERE id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found.';
  END IF;

  -- Validate caller is the vendor
  IF v_conversation.vendor_id <> p_vendor_id THEN
    RAISE EXCEPTION 'Only the vendor can revise a quote.';
  END IF;

  -- Validate conversation is in a stage that allows quote revision
  IF v_conversation.stage NOT IN ('quoted', 'host_reviewing') THEN
    RAISE EXCEPTION 'A quote can only be revised from the quoted or host_reviewing stage.';
  END IF;

  -- Validate previous quote exists and belongs to this conversation
  SELECT *
  INTO v_previous_quote
  FROM public.booking_quotes
  WHERE id = p_previous_quote_id
    AND conversation_id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Previous quote not found.';
  END IF;

  -- Resolve event date for conflict checking
  IF v_conversation.event_id IS NOT NULL THEN
    SELECT (timezone('utc', events.date))::date
    INTO v_event_date
    FROM public.events
    WHERE events.id = v_conversation.event_id;
  END IF;

  -- Check date conflicts
  IF v_event_date IS NOT NULL THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'conversation_id', conflicts.conversation_id,
          'event_title', conflicts.event_title,
          'host_display_name', conflicts.host_display_name,
          'stage', conflicts.stage
        )
      ),
      '[]'::jsonb
    )
    INTO v_date_conflicts
    FROM public.check_vendor_date_conflicts(
      v_conversation.vendor_id,
      v_event_date,
      p_conversation_id
    ) AS conflicts;
  END IF;

  -- Mark previous quote as superseded
  UPDATE public.booking_quotes
  SET status = 'superseded'
  WHERE id = p_previous_quote_id;

  -- Insert new quote
  INSERT INTO public.booking_quotes (
    conversation_id,
    title,
    total_amount_label,
    deposit_amount_label,
    expires_at_label,
    turnaround_label,
    included_items,
    note,
    status,
    total_amount_cents,
    deposit_amount_cents,
    expires_at,
    currency
  )
  VALUES (
    p_conversation_id,
    btrim(p_title),
    btrim(p_total_amount_label),
    btrim(p_deposit_amount_label),
    to_char(p_expires_at AT TIME ZONE 'utc', 'Mon DD, YYYY HH24:MI UTC'),
    btrim(p_turnaround_label),
    coalesce(p_included_items, '{}'::text[]),
    coalesce(p_note, ''),
    'pending',
    p_total_amount_cents,
    p_deposit_amount_cents,
    p_expires_at,
    lower(coalesce(p_currency, 'usd'))
  )
  RETURNING id INTO v_quote_id;

  -- Ensure booking exists and update quote reference
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'host_reviewing');

  UPDATE public.bookings AS existing_booking
  SET quote_id = v_quote_id,
      event_date = coalesce(existing_booking.event_date, v_event_date),
      updated_at = v_now
  WHERE existing_booking.id = v_booking_id;

  -- Reset conversation stage to host_reviewing
  UPDATE public.conversations
  SET stage = 'host_reviewing',
      last_activity_at = v_now
  WHERE id = p_conversation_id;

  -- Insert system message
  INSERT INTO public.messages (
    conversation_id,
    sender_role,
    body,
    kind,
    created_at
  )
  VALUES (
    p_conversation_id,
    'vendor',
    'The vendor sent a revised quote.',
    'quote',
    v_now
  );

  -- Insert booking audit event
  INSERT INTO public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  VALUES (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'host_reviewing',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'quote_id', v_quote_id,
      'previous_quote_id', p_previous_quote_id,
      'expires_at', p_expires_at,
      'conflict_acknowledged', p_conflict_acknowledged,
      'date_conflicts', v_date_conflicts
    ),
    p_idempotency_key
  );

  RETURN public.booking_transition_snapshot(p_conversation_id, v_date_conflicts)
    || jsonb_build_object('quote_id', v_quote_id);
END;
$$;

--------------------------------------------------------------------------------
-- 3. create_conversation_server
--------------------------------------------------------------------------------

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
  v_existing_conversation public.conversations%rowtype;
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

  -- Check for existing conversation with same (host, vendor, event)
  IF p_event_id IS NOT NULL THEN
    SELECT *
    INTO v_existing_conversation
    FROM public.conversations
    WHERE host_id = p_host_id
      AND vendor_id = p_vendor_id
      AND event_id = p_event_id;
  ELSE
    SELECT *
    INTO v_existing_conversation
    FROM public.conversations
    WHERE host_id = p_host_id
      AND vendor_id = p_vendor_id
      AND event_id IS NULL;
  END IF;

  -- Return existing conversation if found
  IF FOUND THEN
    RETURN row_to_json(v_existing_conversation)::jsonb;
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

  -- Insert new conversation
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
  RETURNING id INTO v_conversation_id;

  -- Return the newly created conversation
  RETURN (
    SELECT row_to_json(c.*)::jsonb
    FROM public.conversations c
    WHERE c.id = v_conversation_id
  );
END;
$$;

--------------------------------------------------------------------------------
-- 4. fetch_booking_summaries
--------------------------------------------------------------------------------

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
  -- Validate role
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
      'latest_request_title', latest_request.title,
      'latest_request_budget_label', latest_request.budget_label,
      'latest_request_event_date', latest_request.event_date,
      'latest_quote_id', latest_quote.id,
      'latest_quote_total_label', latest_quote.total_amount_label,
      'latest_quote_status', latest_quote.status,
      'latest_booking_id', latest_booking.id,
      'latest_booking_stage', latest_booking.stage
    ) AS summary,
    c.last_activity_at
    FROM public.conversations c
    LEFT JOIN LATERAL (
      SELECT br.title, br.budget_label, br.event_date
      FROM public.booking_requests br
      WHERE br.conversation_id = c.id
      ORDER BY br.created_at DESC
      LIMIT 1
    ) AS latest_request ON true
    LEFT JOIN LATERAL (
      SELECT bq.id, bq.total_amount_label, bq.status
      FROM public.booking_quotes bq
      WHERE bq.conversation_id = c.id
      ORDER BY bq.created_at DESC
      LIMIT 1
    ) AS latest_quote ON true
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

--------------------------------------------------------------------------------
-- Permissions: grant to service_role only
--------------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.search_vendors_server(text, text, text, date, integer, integer, integer, integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.search_vendors_server(text, text, text, date, integer, integer, integer, integer) TO service_role;

REVOKE ALL ON FUNCTION public.revise_quote_server(uuid, uuid, uuid, text, text, text, integer, integer, timestamptz, text, text[], text, text, boolean, uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revise_quote_server(uuid, uuid, uuid, text, text, text, integer, integer, timestamptz, text, text[], text, text, boolean, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.create_conversation_server(uuid, uuid, uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_conversation_server(uuid, uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.fetch_booking_summaries(uuid, text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_booking_summaries(uuid, text) TO service_role;
