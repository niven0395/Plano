-- =============================================================================
-- Fix cancellation compatibility for legacy confirmed stages
-- =============================================================================

-- Normalize live booking rows so future reloads use the canonical post-payment stage.
update public.conversations
set stage = 'paid'
where stage = 'confirmed';

update public.bookings
set stage = 'paid'
where stage = 'confirmed';

update public.bookings
set stage_before_cancellation_request = 'paid'
where stage_before_cancellation_request = 'confirmed';

create or replace function public.validate_booking_transition_v2(
  from_stage text,
  to_stage text,
  role text
)
returns boolean
language sql
immutable
as $$
  select case
    when from_stage is null or to_stage is null or role is null then false
    when from_stage = to_stage then false
    -- host transitions
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'paid' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true
    -- host -> cancellation_requested (policy-gated)
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true
    -- vendor transitions
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    -- vendor: revert cancellation_requested back to original stage
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'requested' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage in ('paid', 'confirmed') then true
    -- system transitions
    when lower(role) = 'system' and from_stage in ('paid', 'confirmed') and to_stage = 'completed' then true
    else false
  end;
$$;

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
  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.booking_events
      where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conversation.host_id = p_actor_id then
    v_trigger_role := 'host';
  elsif v_conversation.vendor_id = p_actor_id then
    v_trigger_role := 'vendor';
  else
    raise exception 'Only a conversation participant can cancel this booking.';
  end if;

  select *
  into v_booking
  from public.bookings
  where conversation_id = p_conversation_id
  order by updated_at desc nulls last, created_at desc nulls last
  limit 1
  for update;

  v_current_stage := case
    when v_conversation.stage = 'confirmed' then 'paid'
    else v_conversation.stage
  end;

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

  if not public.validate_booking_transition_v2(v_current_stage, 'cancelled', v_trigger_role) then
    raise exception 'This booking cannot be cancelled from the current stage.';
  end if;

  perform public.ensure_booking_for_conversation(p_conversation_id, 'cancelled');

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

create or replace function public.respond_to_cancellation_request_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_approved boolean,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_revert_stage text;
  v_message text;
begin
  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.booking_events
      where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can respond to a cancellation request.';
  end if;

  if v_conversation.stage <> 'cancellation_requested' then
    raise exception 'There is no pending cancellation request for this booking.';
  end if;

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

  if p_approved then
    if not public.validate_booking_transition_v2(v_conversation.stage, 'cancelled', 'vendor') then
      raise exception 'Cannot approve cancellation from the current stage.';
    end if;

    update public.bookings
    set stage = 'cancelled',
        cancelled_by = v_booking.cancellation_requested_by,
        cancelled_at = v_now,
        cancellation_reason = v_booking.cancellation_request_reason,
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

    v_message := 'The vendor approved the cancellation request.';

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
      'cancellation_requested',
      'cancelled',
      p_vendor_id,
      'vendor',
      v_booking.cancellation_request_reason,
      jsonb_build_object(
        'refund_required', coalesce(v_booking.stage_before_cancellation_request, '') in ('paid', 'confirmed'),
        'event_date', v_booking.event_date,
        'approved_by_vendor', true
      ),
      p_idempotency_key
    );
  else
    v_revert_stage := case
      when v_booking.stage_before_cancellation_request = 'confirmed' then 'paid'
      else v_booking.stage_before_cancellation_request
    end;

    if v_revert_stage is null then
      raise exception 'Cannot determine the stage to revert to.';
    end if;

    if not public.validate_booking_transition_v2(v_conversation.stage, v_revert_stage, 'vendor') then
      raise exception 'Cannot decline cancellation request from the current stage.';
    end if;

    update public.bookings
    set stage = v_revert_stage,
        cancellation_requested_by = null,
        cancellation_requested_at = null,
        cancellation_request_reason = null,
        stage_before_cancellation_request = null,
        updated_at = v_now
    where id = v_booking.id;

    update public.conversations
    set stage = v_revert_stage,
        last_activity_at = v_now
    where id = p_conversation_id;

    v_message := 'The cancellation request was declined.';
    if btrim(coalesce(p_reason, '')) <> '' then
      v_message := format('The cancellation request was declined. %s', btrim(p_reason));
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
      'cancellation_requested',
      v_revert_stage,
      p_vendor_id,
      'vendor',
      nullif(btrim(coalesce(p_reason, '')), ''),
      jsonb_build_object(
        'approved_by_vendor', false,
        'reverted_to_stage', v_revert_stage,
        'event_date', v_booking.event_date
      ),
      p_idempotency_key
    );
  end if;

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

revoke all on function public.validate_booking_transition_v2(text, text, text) from public, anon, authenticated;
grant execute on function public.validate_booking_transition_v2(text, text, text) to service_role;

revoke all on function public.cancel_booking_v2(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.cancel_booking_v2(uuid, uuid, text, uuid) to service_role;

revoke all on function public.respond_to_cancellation_request_server(uuid, uuid, boolean, text, uuid) from public, anon, authenticated;
grant execute on function public.respond_to_cancellation_request_server(uuid, uuid, boolean, text, uuid) to service_role;
