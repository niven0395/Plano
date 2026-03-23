-- Fix: confirm_payment_server and vendor_confirm_payment_server use
-- ON CONFLICT (vendor_id, date) but that 2-column unique constraint was
-- dropped in 20260313120000 and replaced with a 3-column expression index
-- (vendor_id, date, coalesce(booking_id, ...)).
--
-- Switch to DELETE + INSERT so the upsert doesn't depend on a specific
-- constraint shape, and also populate booking_id / conversation_id columns
-- that were added in 20260313120000.

-- 1. Recreate confirm_payment_server (host confirms payment)
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
  -- Use DELETE + INSERT to avoid ON CONFLICT mismatch with the
  -- expression-based unique index (vendor_id, date, coalesce(booking_id, ...))
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where booking_id = v_booking_id;

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

-- 2. Recreate vendor_confirm_payment_server
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

  -- Create vendor_availability entry with status='booked'
  -- Use DELETE + INSERT to avoid ON CONFLICT mismatch with the
  -- expression-based unique index (vendor_id, date, coalesce(booking_id, ...))
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where booking_id = v_booking_id;

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
