-- =============================================================================
-- Booking system hardening: availability checks, holds, dedup, date validation,
-- force-cancel cooldown, and auto-complete exclusion of cancellation_requested.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. submit_booking_request_v2: add availability check, date validation,
--    and cross-conversation duplicate prevention
-- ---------------------------------------------------------------------------

-- Drop the previous overload
drop function if exists public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[], jsonb);

create or replace function public.submit_booking_request_v2(
  p_conversation_id uuid,
  p_host_id uuid,
  p_event_date date,
  p_note text,
  p_idempotency_key uuid default null,
  p_requested_time_start time default null,
  p_requested_time_end time default null,
  p_title text default null,
  p_budget_label text default null,
  p_guest_count_label text default null,
  p_requested_services text[] default null,
  p_intake_answers jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_request_id uuid;
  v_now timestamptz := timezone('utc', now());
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

  -- Validate event date is not in the past
  if p_event_date < current_date then
    raise exception 'Event date must be today or in the future.';
  end if;

  if p_requested_time_start is not null
     and p_requested_time_end is not null
     and p_requested_time_end <= p_requested_time_start then
    raise exception 'Requested end time must be later than the start time.';
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

  -- Validate host is participant
  if v_conversation.host_id <> p_host_id then
    raise exception 'Only the host can submit a booking request.';
  end if;

  -- Validate stage allows booking (including re-booking after decline/cancel)
  if v_conversation.stage not in ('active', 'draft', 'declined', 'cancelled') then
    raise exception 'Booking request cannot be submitted from the current stage.';
  end if;

  -- Check for duplicate active bookings with the same vendor across conversations
  if exists (
    select 1
    from public.conversations
    where vendor_id = v_conversation.vendor_id
      and host_id = p_host_id
      and id <> p_conversation_id
      and stage in ('requested', 'accepted', 'payment_requested', 'paid')
  ) then
    raise exception 'You already have an active booking with this vendor.';
  end if;

  -- Check vendor availability for the requested date
  if exists (
    select 1
    from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = p_event_date
      and status in ('booked', 'blocked')
  ) then
    raise exception 'This vendor is not available on the requested date.';
  end if;

  -- Insert booking request with full details
  insert into public.booking_requests (
    conversation_id,
    event_date,
    note,
    requested_time_start,
    requested_time_end,
    title,
    budget_label,
    guest_count_label,
    requested_services,
    intake_answers
  )
  values (
    p_conversation_id,
    p_event_date,
    coalesce(p_note, ''),
    p_requested_time_start,
    p_requested_time_end,
    p_title,
    p_budget_label,
    p_guest_count_label,
    coalesce(p_requested_services, '{}'::text[]),
    coalesce(p_intake_answers, '[]'::jsonb)
  )
  returning id into v_request_id;

  -- Ensure booking exists with stage 'requested'
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'requested');

  -- Update booking event_date
  update public.bookings
  set event_date = p_event_date,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Insert system message
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
    format('Booking requested for %s', to_char(p_event_date, 'Mon DD, YYYY')),
    'system',
    v_now
  );

  -- Insert booking_events audit row
  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'requested',
    p_host_id,
    'host',
    jsonb_build_object(
      'booking_request_id', v_request_id,
      'event_date', p_event_date,
      'requested_time_start', p_requested_time_start,
      'requested_time_end', p_requested_time_end,
      'title', p_title,
      'budget_label', p_budget_label,
      'guest_count_label', p_guest_count_label,
      'intake_answers', coalesce(p_intake_answers, '[]'::jsonb)
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- Permissions
revoke all on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[], jsonb) from public, anon, authenticated;
grant execute on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[], jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 2. accept_booking_server: create availability hold on acceptance
-- ---------------------------------------------------------------------------

create or replace function public.accept_booking_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_booking public.bookings%rowtype;
  v_now timestamptz := timezone('utc', now());
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

  -- Validate vendor is participant
  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can accept this booking.';
  end if;

  -- Validate stage transition
  if not public.validate_booking_transition_v2(v_conversation.stage, 'accepted', 'vendor') then
    raise exception 'Booking cannot be accepted from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'accepted');

  -- Get booking for event_date
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id;

  update public.bookings
  set stage = 'accepted',
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'accepted',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Reserve availability with 'hold' status
  if v_booking.event_date is not null then
    if exists (
      select 1
      from public.vendor_availability va
      where va.vendor_id = v_conversation.vendor_id
        and va.date = v_booking.event_date
        and va.status in ('hold', 'booked', 'blocked')
        and coalesce(va.conversation_id, '00000000-0000-0000-0000-000000000000'::uuid) <> p_conversation_id
    ) then
      raise exception 'This vendor already has a conflicting booking or hold on that date.';
    end if;

    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note,
      booking_id,
      conversation_id
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'hold',
      format('booking:%s', p_conversation_id),
      v_booking_id,
      p_conversation_id
    );
  end if;

  -- Insert system message
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
    'Booking accepted by vendor.',
    'system',
    v_now
  );

  -- Insert booking_events audit row
  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'accepted',
    p_vendor_id,
    'vendor',
    '{}'::jsonb,
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. decline_booking_server: remove hold on decline
-- ---------------------------------------------------------------------------

create or replace function public.decline_booking_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_booking public.bookings%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_message text := 'The vendor declined this request.';
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

  -- Validate vendor is participant
  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can decline this request.';
  end if;

  -- Validate stage transition (only from 'requested')
  if not public.validate_booking_transition_v2(v_conversation.stage, 'declined', 'vendor') then
    raise exception 'Requests can only be declined while they are awaiting vendor review.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'declined');

  -- Get booking for event_date (to clean up any hold)
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id;

  update public.bookings
  set stage = 'declined',
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'declined',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Remove any availability hold for this booking
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and note = format('booking:%s', p_conversation_id);
  end if;

  -- Build message with optional reason
  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('The vendor declined this request. %s', btrim(p_reason));
  end if;

  -- Insert system message
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

  -- Insert booking_events audit row
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
    v_booking_id,
    v_conversation.stage,
    'declined',
    p_vendor_id,
    'vendor',
    nullif(btrim(coalesce(p_reason, '')), ''),
    jsonb_build_object('reason_provided', btrim(coalesce(p_reason, '')) <> ''),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. confirm_payment_server: upgrade hold → booked
-- ---------------------------------------------------------------------------

create or replace function public.confirm_payment_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
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

  -- Validate host is participant
  if v_conversation.host_id <> p_host_id then
    raise exception 'Only the host can confirm payment.';
  end if;

  -- Validate stage transition: payment_requested -> paid
  if not public.validate_booking_transition_v2(v_conversation.stage, 'paid', 'host') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  -- Get booking for event_date
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id
  for update;

  -- Update booking with payment confirmation
  update public.bookings
  set stage = 'paid',
      payment_confirmed_at = v_now,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'paid',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Upgrade availability hold → booked (or insert if missing)
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note,
      booking_id,
      conversation_id
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'booked',
      format('booking:%s', p_conversation_id),
      v_booking_id,
      p_conversation_id
    );
  end if;

  -- Insert system message
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
    'Payment confirmed. Booking is now paid.',
    'system',
    v_now
  );

  -- Insert booking_events audit row
  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'paid',
    p_host_id,
    'host',
    jsonb_build_object(
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. vendor_confirm_payment_server: upgrade hold → booked
-- ---------------------------------------------------------------------------

create or replace function public.vendor_confirm_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
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

  -- Validate vendor is participant
  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can confirm payment.';
  end if;

  -- Validate stage transition: payment_requested -> paid
  if not public.validate_booking_transition_v2(v_conversation.stage, 'paid', 'vendor') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  -- Get booking for event_date
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id
  for update;

  -- Update booking with payment confirmation
  update public.bookings
  set stage = 'paid',
      payment_confirmed_at = v_now,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'paid',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Upgrade availability hold → booked (or insert if missing)
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note,
      booking_id,
      conversation_id
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'booked',
      format('booking:%s', p_conversation_id),
      v_booking_id,
      p_conversation_id
    );
  end if;

  -- Insert system message
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
    'Vendor confirmed payment received. Booking is now paid.',
    'system',
    v_now
  );

  -- Insert booking_events audit row
  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'paid',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. force_cancel_booking: add 24-hour cooldown after decline
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

  -- Cooldown: 24 hours must pass after decline before force-cancel
  if v_booking.cancellation_declined_at + interval '24 hours' > v_now then
    raise exception 'Force-cancel is available 24 hours after the cancellation request was declined. Please try again later.';
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
-- 7. complete_past_bookings: exclude cancellation_requested, add 1-day grace
-- ---------------------------------------------------------------------------

create or replace function public.complete_past_bookings()
returns jsonb[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_results jsonb[] := '{}';
  v_now timestamptz := timezone('utc', now());
begin
  for v_row in
    select b.id as booking_id,
           b.conversation_id,
           b.event_date,
           c.host_id,
           c.vendor_id,
           c.stage as conversation_stage
    from public.bookings b
    join public.conversations c on c.id = b.conversation_id
    where b.stage in ('paid', 'confirmed')
      and b.event_date is not null
      and b.event_date < current_date - interval '1 day'
    for update of b skip locked
  loop
    -- Skip bookings in cancellation_requested (handled by auto_resolve)
    if v_row.conversation_stage = 'cancellation_requested' then
      continue;
    end if;

    -- Validate the transition
    if not public.validate_booking_transition_v2('paid', 'completed', 'system')
       and not public.validate_booking_transition('confirmed', 'completed', 'system') then
      continue;
    end if;

    -- Update booking stage
    update public.bookings
    set stage = 'completed',
        updated_at = v_now
    where id = v_row.booking_id;

    -- Update conversation stage
    update public.conversations
    set stage = 'completed',
        last_activity_at = v_now
    where id = v_row.conversation_id;

    -- Insert system message
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
      'This event has concluded. The booking is now complete.',
      'text',
      v_now
    );

    -- Insert audit record
    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      metadata
    )
    values (
      v_row.conversation_id,
      v_row.booking_id,
      v_row.conversation_stage,
      'completed',
      null,
      'system',
      jsonb_build_object(
        'event_type', 'auto_completed',
        'event_date', v_row.event_date
      )
    );

    v_results := array_append(v_results, jsonb_build_object(
      'conversation_id', v_row.conversation_id,
      'host_id', v_row.host_id,
      'vendor_id', v_row.vendor_id
    ));
  end loop;

  return v_results;
end;
$$;
