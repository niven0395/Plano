-- =============================================================================
-- Fix cancel_booking_v2: reorder booking fetch after ensure, add NOT FOUND guard
-- =============================================================================
-- The previous version fetched v_booking BEFORE ensure_booking_for_conversation,
-- so v_booking.id could be NULL when no booking row existed yet. This caused
-- UPDATE bookings WHERE id = NULL to update zero rows, leaving the booking
-- record in its old stage while the conversation moved to 'cancelled'.

create or replace function public.cancel_booking_v2(
  p_conversation_id uuid,
  p_actor_id uuid,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_trigger_role text;
  v_now timestamptz := timezone('utc', now());
  v_message text := 'The booking was cancelled.';
  v_cancellation_deadline_days integer;
  v_deadline_date date;
  v_needs_approval boolean := false;
  v_current_stage text;
begin
  -- Idempotency check
  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.booking_events
      where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  -- Lock conversation
  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  -- Determine role
  if v_conversation.host_id = p_actor_id then
    v_trigger_role := 'host';
  elsif v_conversation.vendor_id = p_actor_id then
    v_trigger_role := 'vendor';
  else
    raise exception 'Only a conversation participant can cancel this booking.';
  end if;

  -- Normalize legacy 'confirmed' stage
  v_current_stage := case
    when v_conversation.stage = 'confirmed' then 'paid'
    else v_conversation.stage
  end;

  -- Ensure a booking row exists (creates one if missing), then fetch it
  perform public.ensure_booking_for_conversation(p_conversation_id);

  select *
  into v_booking
  from public.bookings
  where conversation_id = p_conversation_id
  order by updated_at desc nulls last, created_at desc nulls last
  limit 1
  for update;

  if not found then
    raise exception 'Booking not found.';
  end if;

  -- Policy-aware cancellation for hosts
  if v_trigger_role = 'host' then
    select vp.cancellation_deadline_days
    into v_cancellation_deadline_days
    from public.vendor_profiles vp
    where vp.user_id = v_conversation.vendor_id;

    if v_cancellation_deadline_days is not null
       and v_booking.event_date is not null
       and v_booking.event_date >= current_date then
      v_deadline_date := v_booking.event_date - v_cancellation_deadline_days;
      if current_date >= v_deadline_date then
        v_needs_approval := true;
      end if;
    end if;
  end if;

  -- -----------------------------------------------------------------------
  -- PATH A: cancellation_requested (policy requires vendor approval)
  -- -----------------------------------------------------------------------
  if v_needs_approval then
    if not public.validate_booking_transition_v2(v_current_stage, 'cancellation_requested', v_trigger_role) then
      raise exception 'This booking cannot be cancelled from the current stage.';
    end if;

    update public.bookings
    set stage = 'cancellation_requested',
        cancellation_requested_by = p_actor_id,
        cancellation_requested_at = v_now,
        cancellation_request_reason = nullif(btrim(coalesce(p_reason, '')), ''),
        stage_before_cancellation_request = v_current_stage,
        updated_at = v_now
    where id = v_booking.id;

    update public.conversations
    set stage = 'cancellation_requested',
        last_activity_at = v_now
    where id = p_conversation_id;

    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      p_conversation_id,
      'system',
      'A cancellation request has been submitted. The vendor''s cancellation policy requires their approval.',
      'system',
      v_now
    );

    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      reason,
      metadata,
      idempotency_key
    )
    values (
      p_conversation_id,
      v_booking.id,
      v_current_stage,
      'cancellation_requested',
      p_actor_id,
      v_trigger_role,
      nullif(btrim(coalesce(p_reason, '')), ''),
      jsonb_build_object(
        'cancellation_deadline_days', v_cancellation_deadline_days,
        'deadline_date', v_deadline_date,
        'event_date', v_booking.event_date
      ),
      p_idempotency_key
    );

    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  -- -----------------------------------------------------------------------
  -- PATH B: direct cancellation
  -- -----------------------------------------------------------------------
  if not public.validate_booking_transition_v2(v_current_stage, 'cancelled', v_trigger_role) then
    raise exception 'This booking cannot be cancelled from the current stage.';
  end if;

  update public.bookings
  set stage = 'cancelled',
      cancelled_by = p_actor_id,
      cancelled_at = v_now,
      cancellation_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      updated_at = v_now
  where id = v_booking.id;

  update public.conversations
  set stage = 'cancelled',
      last_activity_at = v_now
  where id = p_conversation_id;

  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and note = format('booking:%s', p_conversation_id);
  end if;

  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('The booking was cancelled. %s', btrim(p_reason));
  end if;

  insert into public.messages (
    conversation_id,
    sender_role,
    body,
    kind,
    created_at
  )
  values (
    p_conversation_id,
    'system',
    v_message,
    'system',
    v_now
  );

  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    reason,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking.id,
    v_current_stage,
    'cancelled',
    p_actor_id,
    v_trigger_role,
    nullif(btrim(coalesce(p_reason, '')), ''),
    jsonb_build_object(
      'refund_required', v_current_stage in ('paid', 'confirmed'),
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- Permissions: service_role only
revoke all on function public.cancel_booking_v2(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.cancel_booking_v2(uuid, uuid, text, uuid) to service_role;
