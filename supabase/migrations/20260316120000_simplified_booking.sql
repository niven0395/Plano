-- =============================================================================
-- Simplified booking state machine: 8 states instead of 11
-- States: active, requested, accepted, declined, payment_requested, paid,
--         cancelled, completed
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Update CHECK constraints to include both old and new values
-- ---------------------------------------------------------------------------

-- conversations.stage
alter table public.conversations drop constraint if exists conversations_stage_check;
alter table public.conversations add constraint conversations_stage_check check (
  stage in (
    'draft', 'active', 'requested', 'vendor_reviewing', 'quoted', 'host_reviewing',
    'accepted', 'deposit_pending', 'confirmed', 'declined', 'cancelled', 'completed',
    'payment_requested', 'paid'
  )
);

-- bookings.stage
alter table public.bookings drop constraint if exists bookings_stage_check;
alter table public.bookings add constraint bookings_stage_check check (
  stage in (
    'draft', 'active', 'requested', 'vendor_reviewing', 'quoted', 'host_reviewing',
    'accepted', 'deposit_pending', 'confirmed', 'declined', 'cancelled', 'completed',
    'payment_requested', 'paid'
  )
);

-- booking_events.from_stage
alter table public.booking_events drop constraint if exists booking_events_from_stage_check;
alter table public.booking_events add constraint booking_events_from_stage_check check (
  from_stage in (
    'draft', 'active', 'requested', 'vendor_reviewing', 'quoted', 'host_reviewing',
    'accepted', 'deposit_pending', 'confirmed', 'declined', 'cancelled', 'completed',
    'payment_requested', 'paid'
  )
);

-- booking_events.to_stage
alter table public.booking_events drop constraint if exists booking_events_to_stage_check;
alter table public.booking_events add constraint booking_events_to_stage_check check (
  to_stage in (
    'draft', 'active', 'requested', 'vendor_reviewing', 'quoted', 'host_reviewing',
    'accepted', 'deposit_pending', 'confirmed', 'declined', 'cancelled', 'completed',
    'payment_requested', 'paid'
  )
);

-- ---------------------------------------------------------------------------
-- 2. Add payment columns to bookings
-- ---------------------------------------------------------------------------

alter table public.bookings add column if not exists payment_requested_amount_cents integer;
alter table public.bookings add column if not exists payment_requested_at timestamptz;
alter table public.bookings add column if not exists payment_confirmed_at timestamptz;
alter table public.bookings add column if not exists payment_reminder_sent_at timestamptz;

-- ---------------------------------------------------------------------------
-- 3. Make booking_requests columns nullable for simplified flow
-- ---------------------------------------------------------------------------

alter table public.booking_requests alter column title drop not null;
alter table public.booking_requests alter column budget_label drop not null;
alter table public.booking_requests alter column response_window_label drop not null;
alter table public.booking_requests alter column guest_count_label drop not null;
alter table public.booking_requests alter column requested_services set default '{}'::text[];

-- ---------------------------------------------------------------------------
-- 4. Loosen messages.kind CHECK to include 'system' and 'payment_request'
-- ---------------------------------------------------------------------------

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check check (
  kind in ('text', 'booking_request', 'quote', 'payment_receipt', 'attachment', 'system', 'payment_request')
);

-- ---------------------------------------------------------------------------
-- 5. New simplified SQL functions
-- ---------------------------------------------------------------------------

-- validate_booking_transition_v2
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
    when lower(role) = 'host' and from_stage = 'paid' and to_stage = 'cancelled' then true
    -- vendor transitions
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'paid' and to_stage = 'cancelled' then true
    -- system transitions
    when lower(role) = 'system' and from_stage = 'paid' and to_stage = 'completed' then true
    else false
  end;
$$;

-- submit_booking_request_v2
create or replace function public.submit_booking_request_v2(
  p_conversation_id uuid,
  p_host_id uuid,
  p_event_date date,
  p_note text,
  p_idempotency_key uuid default null
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

  -- Validate stage is 'active' or 'draft' (allow both for compat)
  if v_conversation.stage not in ('active', 'draft') then
    raise exception 'Booking request cannot be submitted from the current stage.';
  end if;

  -- Insert booking request with simplified fields
  insert into public.booking_requests (
    conversation_id,
    event_date,
    note
  )
  values (
    p_conversation_id,
    p_event_date,
    coalesce(p_note, '')
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
      'event_date', p_event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- accept_booking_server
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

  update public.bookings
  set stage = 'accepted',
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'accepted',
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

-- decline_booking_server
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

  update public.bookings
  set stage = 'declined',
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'declined',
      last_activity_at = v_now
  where id = p_conversation_id;

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

-- request_payment_server
create or replace function public.request_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_amount_cents integer,
  p_note text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_amount_label text;
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

  -- Validate amount
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'A positive payment amount is required.';
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
    raise exception 'Only the vendor can request payment.';
  end if;

  -- Validate stage transition: accepted -> payment_requested
  if not public.validate_booking_transition_v2(v_conversation.stage, 'payment_requested', 'vendor') then
    raise exception 'Payment cannot be requested from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'payment_requested');

  -- Update booking with payment details
  update public.bookings
  set stage = 'payment_requested',
      payment_requested_amount_cents = p_amount_cents,
      payment_requested_at = v_now,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'payment_requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Format currency for system message
  v_amount_label := '$' || to_char(p_amount_cents / 100.0, 'FM999,999,990.00');

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
    format('Payment of %s requested.', v_amount_label),
    'payment_request',
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
    'payment_requested',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', coalesce(p_note, '')
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- confirm_payment_server
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

  -- Create vendor_availability entry with status='booked'
  if v_booking.event_date is not null then
    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'booked',
      format('booking:%s', p_conversation_id)
    )
    on conflict (vendor_id, date)
    do update set
      status = excluded.status,
      note = excluded.note;
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

-- cancel_booking_v2
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

  -- Validate stage transition using v2
  if not public.validate_booking_transition_v2(v_conversation.stage, 'cancelled', v_trigger_role) then
    raise exception 'This booking cannot be cancelled from the current stage.';
  end if;

  -- Ensure booking exists
  perform public.ensure_booking_for_conversation(p_conversation_id, 'cancelled');

  -- Get booking for update
  select *
  into v_booking
  from public.bookings
  where conversation_id = p_conversation_id
  order by updated_at desc nulls last, created_at desc nulls last
  limit 1
  for update;

  -- Update booking
  update public.bookings
  set stage = 'cancelled',
      cancelled_by = p_actor_id,
      cancelled_at = v_now,
      cancellation_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      updated_at = v_now
  where id = v_booking.id;

  -- Update conversation stage
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

  -- Build message with optional reason
  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('The booking was cancelled. %s', btrim(p_reason));
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
    v_booking.id,
    v_conversation.stage,
    'cancelled',
    p_actor_id,
    v_trigger_role,
    nullif(btrim(coalesce(p_reason, '')), ''),
    jsonb_build_object(
      'refund_required', v_conversation.stage = 'paid',
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- Update complete_past_bookings to look for 'paid' instead of 'confirmed'
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
      and b.event_date < current_date
    for update of b
  loop
    -- Validate the transition using both v1 and v2
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

-- ---------------------------------------------------------------------------
-- 6. Grant permissions: service_role only for all new functions
-- ---------------------------------------------------------------------------

revoke all on function public.validate_booking_transition_v2(text, text, text) from public, anon, authenticated;
grant execute on function public.validate_booking_transition_v2(text, text, text) to service_role;

revoke all on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid) from public, anon, authenticated;
grant execute on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid) to service_role;

revoke all on function public.accept_booking_server(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.accept_booking_server(uuid, uuid, uuid) to service_role;

revoke all on function public.decline_booking_server(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.decline_booking_server(uuid, uuid, text, uuid) to service_role;

revoke all on function public.request_payment_server(uuid, uuid, integer, text, uuid) from public, anon, authenticated;
grant execute on function public.request_payment_server(uuid, uuid, integer, text, uuid) to service_role;

revoke all on function public.confirm_payment_server(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.confirm_payment_server(uuid, uuid, uuid) to service_role;

revoke all on function public.cancel_booking_v2(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.cancel_booking_v2(uuid, uuid, text, uuid) to service_role;

revoke all on function public.complete_past_bookings() from public, anon, authenticated;
grant execute on function public.complete_past_bookings() to service_role;
