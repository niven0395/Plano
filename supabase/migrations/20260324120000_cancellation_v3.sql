-- =============================================================================
-- Cancellation v3: symmetric cancellation, force-cancel, auto-resolve
--
-- Core principle: the cancellation policy boundary is payment.
-- Pre-payment: either party cancels directly, no approval needed.
-- Post-payment (paid): counterparty gets a voice via cancellation_requested,
--   with 48-hour auto-resolve timeout and force-cancel as last resort.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Schema changes to bookings
-- ---------------------------------------------------------------------------

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS cancellation_request_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS cancellation_response_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS cancellation_declined_at timestamptz,
  ADD COLUMN IF NOT EXISTS force_cancelled boolean DEFAULT false;

-- ---------------------------------------------------------------------------
-- 2. Updated transition validator
-- ---------------------------------------------------------------------------

create or replace function public.validate_booking_transition_v3(
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

    -- host transitions (non-cancellation)
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'paid' then true

    -- host direct cancel (pre-payment: always allowed)
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    -- host direct cancel (post-payment: allowed when no policy or outside deadline)
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true

    -- host -> cancellation_requested (post-payment, policy-gated)
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true

    -- host responds to vendor's cancellation request
    when lower(role) = 'host' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'cancellation_requested' and to_stage = 'paid' then true

    -- vendor transitions (non-cancellation)
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true

    -- vendor direct cancel (pre-payment: always allowed)
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true

    -- vendor -> cancellation_requested (post-payment: always requires host approval)
    when lower(role) = 'vendor' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true

    -- vendor responds to host's cancellation request
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'paid' then true

    -- system transitions
    when lower(role) = 'system' and from_stage in ('paid', 'confirmed') and to_stage = 'completed' then true
    when lower(role) = 'system' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true

    else false
  end;
$$;

-- ---------------------------------------------------------------------------
-- 3. cancel_booking_v3: policy boundary is payment
-- ---------------------------------------------------------------------------

create or replace function public.cancel_booking_v3(
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
  v_current_stage text;
  v_needs_approval boolean := false;
  v_cancellation_deadline_days integer;
  v_deadline_date date;
  v_counterparty_id uuid;
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
    v_counterparty_id := v_conversation.vendor_id;
  elsif v_conversation.vendor_id = p_actor_id then
    v_trigger_role := 'vendor';
    v_counterparty_id := v_conversation.host_id;
  else
    raise exception 'Only a conversation participant can cancel this booking.';
  end if;

  -- Normalize legacy stage
  v_current_stage := case
    when v_conversation.stage = 'confirmed' then 'paid'
    else v_conversation.stage
  end;

  -- Ensure booking row exists, then fetch it
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

  -- -----------------------------------------------------------------------
  -- Determine if approval is needed
  -- Only post-payment (paid) bookings can require approval
  -- -----------------------------------------------------------------------
  if v_current_stage in ('paid', 'confirmed') then
    if v_trigger_role = 'vendor' then
      -- Vendor cancelling a paid booking: always needs host approval
      v_needs_approval := true;
    elsif v_trigger_role = 'host' then
      -- Host cancelling a paid booking: check vendor's cancellation policy
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
  end if;
  -- Pre-payment stages: v_needs_approval stays false → direct cancel

  -- -----------------------------------------------------------------------
  -- PATH A: cancellation_requested (post-payment, approval required)
  -- -----------------------------------------------------------------------
  if v_needs_approval then
    if not public.validate_booking_transition_v3(v_current_stage, 'cancellation_requested', v_trigger_role) then
      raise exception 'This booking cannot be cancelled from the current stage.';
    end if;

    update public.bookings
    set stage = 'cancellation_requested',
        cancellation_requested_by = p_actor_id,
        cancellation_requested_at = v_now,
        cancellation_request_reason = nullif(btrim(coalesce(p_reason, '')), ''),
        stage_before_cancellation_request = v_current_stage,
        cancellation_request_deadline = v_now + interval '48 hours',
        cancellation_response_by = v_counterparty_id,
        cancellation_declined_at = null,
        force_cancelled = false,
        updated_at = v_now
    where id = v_booking.id;

    update public.conversations
    set stage = 'cancellation_requested',
        last_activity_at = v_now
    where id = p_conversation_id;

    -- Build role-appropriate system message
    if v_trigger_role = 'host' then
      v_message := 'A cancellation request has been submitted. The vendor''s cancellation policy requires their approval.';
    else
      v_message := 'The vendor has requested to cancel this booking. The host must approve or decline.';
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
      'cancellation_requested',
      p_actor_id,
      v_trigger_role,
      nullif(btrim(coalesce(p_reason, '')), ''),
      jsonb_build_object(
        'cancellation_deadline_days', v_cancellation_deadline_days,
        'deadline_date', v_deadline_date,
        'event_date', v_booking.event_date,
        'response_by', v_counterparty_id,
        'auto_resolve_at', v_now + interval '48 hours'
      ),
      p_idempotency_key
    );

    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  -- -----------------------------------------------------------------------
  -- PATH B: direct cancellation (pre-payment, or post-payment without policy)
  -- -----------------------------------------------------------------------
  if not public.validate_booking_transition_v3(v_current_stage, 'cancelled', v_trigger_role) then
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

  -- Remove vendor availability if event_date exists
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

-- ---------------------------------------------------------------------------
-- 4. respond_to_cancellation_request_v2: role-aware (host or vendor responds)
-- ---------------------------------------------------------------------------

create or replace function public.respond_to_cancellation_request_v2(
  p_conversation_id uuid,
  p_responder_id uuid,
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
  v_responder_role text;
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

  -- Validate conversation is in cancellation_requested stage
  if v_conversation.stage <> 'cancellation_requested' then
    raise exception 'There is no pending cancellation request for this booking.';
  end if;

  -- Get booking for update
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

  -- Validate responder is the designated counterparty
  if v_booking.cancellation_response_by is not null
     and v_booking.cancellation_response_by <> p_responder_id then
    raise exception 'Only the designated counterparty can respond to this cancellation request.';
  end if;

  -- Determine responder role
  if v_conversation.host_id = p_responder_id then
    v_responder_role := 'host';
  elsif v_conversation.vendor_id = p_responder_id then
    v_responder_role := 'vendor';
  else
    raise exception 'Only a conversation participant can respond to a cancellation request.';
  end if;

  if p_approved then
    -- -----------------------------------------------------------------------
    -- APPROVE: transition to cancelled
    -- -----------------------------------------------------------------------
    if not public.validate_booking_transition_v3(v_conversation.stage, 'cancelled', v_responder_role) then
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

    -- Remove vendor availability if event_date exists
    if v_booking.event_date is not null then
      delete from public.vendor_availability
      where vendor_id = v_conversation.vendor_id
        and date = v_booking.event_date
        and note = format('booking:%s', p_conversation_id);
    end if;

    if v_responder_role = 'vendor' then
      v_message := 'The vendor approved the cancellation request.';
    else
      v_message := 'The host approved the cancellation request.';
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
      'cancelled',
      p_responder_id,
      v_responder_role,
      v_booking.cancellation_request_reason,
      jsonb_build_object(
        'refund_required', coalesce(v_booking.stage_before_cancellation_request, '') in ('paid', 'confirmed'),
        'event_date', v_booking.event_date,
        'approved_by', v_responder_role
      ),
      p_idempotency_key
    );

  else
    -- -----------------------------------------------------------------------
    -- DECLINE: revert to stage_before_cancellation_request
    -- -----------------------------------------------------------------------
    v_revert_stage := case
      when v_booking.stage_before_cancellation_request = 'confirmed' then 'paid'
      else v_booking.stage_before_cancellation_request
    end;

    if v_revert_stage is null then
      raise exception 'Cannot determine the stage to revert to.';
    end if;

    if not public.validate_booking_transition_v3(v_conversation.stage, v_revert_stage, v_responder_role) then
      raise exception 'Cannot decline cancellation request from the current stage.';
    end if;

    -- Revert booking stage but PRESERVE cancellation_requested_by and reason
    -- (needed for force-cancel UI context)
    update public.bookings
    set stage = v_revert_stage,
        cancellation_declined_at = v_now,
        cancellation_request_deadline = null,
        cancellation_response_by = null,
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
      p_responder_id,
      v_responder_role,
      nullif(btrim(coalesce(p_reason, '')), ''),
      jsonb_build_object(
        'declined_by', v_responder_role,
        'reverted_to_stage', v_revert_stage,
        'event_date', v_booking.event_date
      ),
      p_idempotency_key
    );
  end if;

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. force_cancel_booking: last resort after decline
-- ---------------------------------------------------------------------------

create or replace function public.force_cancel_booking(
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
  v_now timestamptz := timezone('utc', now());
  v_trigger_role text;
  v_message text;
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

  -- Get booking
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

  -- Already cancelled? Return current snapshot (idempotent)
  if v_conversation.stage = 'cancelled' then
    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  -- Guard: only the original requester whose request was declined can force-cancel
  if v_booking.cancellation_declined_at is null then
    raise exception 'Force-cancel is only available after a cancellation request has been declined.';
  end if;

  if v_booking.cancellation_requested_by <> p_actor_id then
    raise exception 'Only the party whose cancellation request was declined can force-cancel.';
  end if;

  -- Determine role
  if v_conversation.host_id = p_actor_id then
    v_trigger_role := 'host';
  elsif v_conversation.vendor_id = p_actor_id then
    v_trigger_role := 'vendor';
  else
    raise exception 'Only a conversation participant can cancel this booking.';
  end if;

  v_current_stage := v_conversation.stage;

  -- Transition to cancelled
  update public.bookings
  set stage = 'cancelled',
      cancelled_by = p_actor_id,
      cancelled_at = v_now,
      cancellation_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      force_cancelled = true,
      updated_at = v_now
  where id = v_booking.id;

  update public.conversations
  set stage = 'cancelled',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Remove vendor availability
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and note = format('booking:%s', p_conversation_id);
  end if;

  v_message := 'The booking was cancelled. The cancellation was processed despite the earlier decline.';
  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('%s %s', v_message, btrim(p_reason));
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
      'force_cancelled', true,
      'refund_required', v_current_stage in ('paid', 'confirmed'),
      'event_date', v_booking.event_date,
      'declined_at', v_booking.cancellation_declined_at
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. auto_resolve_cancellation_requests: pg_cron job target
-- ---------------------------------------------------------------------------

create or replace function public.auto_resolve_cancellation_requests()
returns integer
language plpgsql
as $$
declare
  v_row record;
  v_count integer := 0;
  v_now timestamptz := timezone('utc', now());
begin
  for v_row in
    select b.id as booking_id,
           b.conversation_id,
           b.event_date,
           b.cancellation_requested_by,
           b.cancellation_request_reason,
           b.stage_before_cancellation_request,
           c.vendor_id
    from public.bookings b
    join public.conversations c on c.id = b.conversation_id
    where b.stage = 'cancellation_requested'
      and b.cancellation_request_deadline is not null
      and b.cancellation_request_deadline < v_now
    for update of b skip locked
  loop
    -- Transition booking to cancelled
    update public.bookings
    set stage = 'cancelled',
        cancelled_by = v_row.cancellation_requested_by,
        cancelled_at = v_now,
        cancellation_reason = v_row.cancellation_request_reason,
        updated_at = v_now
    where id = v_row.booking_id;

    -- Transition conversation to cancelled
    update public.conversations
    set stage = 'cancelled',
        last_activity_at = v_now
    where id = v_row.conversation_id;

    -- Remove vendor availability
    if v_row.event_date is not null then
      delete from public.vendor_availability
      where vendor_id = v_row.vendor_id
        and date = v_row.event_date
        and note = format('booking:%s', v_row.conversation_id);
    end if;

    -- System message
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_row.conversation_id,
      'system',
      'The cancellation request was automatically approved after 48 hours with no response.',
      'system',
      v_now
    );

    -- Audit event
    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      reason,
      metadata
    )
    values (
      v_row.conversation_id,
      v_row.booking_id,
      'cancellation_requested',
      'cancelled',
      v_row.cancellation_requested_by,
      'system',
      'Auto-resolved: no response within 48 hours',
      jsonb_build_object(
        'auto_resolved', true,
        'refund_required', coalesce(v_row.stage_before_cancellation_request, '') in ('paid', 'confirmed'),
        'event_date', v_row.event_date
      )
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Update booking_transition_snapshot with new fields
-- ---------------------------------------------------------------------------

create or replace function public.booking_transition_snapshot(
  p_conversation_id uuid,
  p_date_conflicts jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'conversation_id', conversations.id,
    'stage', conversations.stage,
    'booking_id', booking_row.id,
    'date_conflicts', coalesce(p_date_conflicts, '[]'::jsonb),
    'cancellation_request_deadline', booking_row.cancellation_request_deadline,
    'cancellation_response_by', booking_row.cancellation_response_by,
    'cancellation_requested_by', booking_row.cancellation_requested_by,
    'cancellation_declined_at', booking_row.cancellation_declined_at,
    'force_cancelled', coalesce(booking_row.force_cancelled, false)
  )
  from public.conversations
  left join lateral (
    select bookings.*
    from public.bookings
    where bookings.conversation_id = conversations.id
    order by bookings.updated_at desc nulls last, bookings.created_at desc nulls last
    limit 1
  ) as booking_row on true
  where conversations.id = p_conversation_id;
$$;

-- ---------------------------------------------------------------------------
-- 8. Cron job for auto-resolution (every 15 minutes)
-- ---------------------------------------------------------------------------

-- Note: pg_cron must be enabled on the Supabase project.
-- If pg_cron is not available, this will be a no-op.
do $outer$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'auto-resolve-cancellation-requests',
      '*/15 * * * *',
      'select public.auto_resolve_cancellation_requests()'
    );
  end if;
end;
$outer$;

-- ---------------------------------------------------------------------------
-- 9. Permissions
-- ---------------------------------------------------------------------------

revoke all on function public.validate_booking_transition_v3(text, text, text) from public, anon, authenticated;
grant execute on function public.validate_booking_transition_v3(text, text, text) to service_role;

revoke all on function public.cancel_booking_v3(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.cancel_booking_v3(uuid, uuid, text, uuid) to service_role;

revoke all on function public.respond_to_cancellation_request_v2(uuid, uuid, boolean, text, uuid) from public, anon, authenticated;
grant execute on function public.respond_to_cancellation_request_v2(uuid, uuid, boolean, text, uuid) to service_role;

revoke all on function public.force_cancel_booking(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.force_cancel_booking(uuid, uuid, text, uuid) to service_role;

revoke all on function public.auto_resolve_cancellation_requests() from public, anon, authenticated;
grant execute on function public.auto_resolve_cancellation_requests() to service_role;
